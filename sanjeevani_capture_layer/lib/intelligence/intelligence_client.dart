/// HTTP client for the intelligence layer (local llama-server).
///
/// ════════════════════════════════════════════════════════════════════════
/// WHY THIS IS NOT A GRADIO CLIENT
/// ════════════════════════════════════════════════════════════════════════
///
/// Gradio is incompatible with Sanjeevani for three concrete reasons:
///
/// 1. GRADIO IS A SERVER, NOT A LIBRARY.
///    `demo.launch()` starts an HTTP server and that server IS the application.
///    Sanjeevani must work with zero connectivity in rural villages.
///    A server dependency — even a local one managed by Gradio — means
///    the application depends on Gradio's process manager, its port binding,
///    its startup time, and its error states. That is too many dependencies
///    between a health worker and a medical recommendation.
///
/// 2. GRADIO'S `share=True` ROUTES PATIENT DATA THROUGH THE PUBLIC INTERNET.
///    To reach the app from a phone on a different device, Gradio's `share=True`
///    creates a tunnel through `gradio.live` — a third-party public endpoint.
///    Patient health conversations are sensitive health data. Routing them
///    through a third party is a privacy violation.
///
/// 3. GRADIO ASSUMES A BROWSER UI.
///    Sanjeevani's UI is Flutter. Running Gradio alongside Flutter means two
///    applications that cannot share SQLite patient records, cannot share the
///    voice/STT pipeline, and cannot be packaged as a single APK.
///
/// THE CORRECT ARCHITECTURE:
///    This class calls `llama-server` (part of the llama.cpp project),
///    a minimal C++ HTTP server that runs the quantized GGUF model locally.
///    It binds to 127.0.0.1 (loopback) ONLY — physically unreachable from
///    any other device. This class validates that constraint at construction.
///
/// ════════════════════════════════════════════════════════════════════════
/// SECURITY PROPERTIES ENFORCED IN CODE
/// ════════════════════════════════════════════════════════════════════════
///
///   - [_assertLoopback] raises before any network call if the configured
///     host is not a loopback address. This is not a soft warning.
///   - No credentials, API keys, or tokens are used by this client.
///   - No patient data is logged — requests and responses are logged at
///     the structural level only (status codes, latency, char counts).
///   - All exceptions from `package:http` are caught and re-thrown as
///     [IntelligenceLayerException] so callers handle ONE exception type.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart';

class IntelligenceClient {
  IntelligenceClient({
    String? host,
    int? port,
    http.Client? httpClient,
  })  : _host = host ?? IntelligenceConfig.host,
        _port = port ?? IntelligenceConfig.port,
        _http = httpClient ?? http.Client() {
    // Security: refuse to construct against a non-loopback address.
    _assertLoopback(_host);
    _log.info('IntelligenceClient configured: $_host:$_port');
  }

  final String _host;
  final int _port;
  final http.Client _http;
  final _log = Logger('sanjeevani.capture.intelligence');

  static const _loopbackHosts = {'127.0.0.1', 'localhost', '::1'};

  /// Throws [IntelligenceLayerException] for any non-loopback host.
  ///
  /// This check cannot be bypassed. Pointing this client at a real
  /// network address would silently route patient health data off-device.
  static void _assertLoopback(String host) {
    final isLoopback = _loopbackHosts.contains(host) ||
        (InternetAddress.tryParse(host)?.isLoopback ?? false);
    if (!isLoopback) {
      throw IntelligenceLayerException(
        'SECURITY VIOLATION: IntelligenceClient refuses to connect to '
        '"$host". The on-device intelligence backend must only communicate '
        'with 127.0.0.1 (loopback). Connecting to any other address would '
        'route patient health data off-device. '
        'This restriction is not configurable.',
      );
    }
  }

  /// Check if the local llama-server is running and ready.
  ///
  /// Returns false (not throws) when the server is not reachable.
  /// Call this at app startup to show a friendly error before accepting input.
  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('http://$_host:$_port/health');
      final response = await _http.get(uri).timeout(
        IntelligenceConfig.healthCheckTimeout,
      );
      final healthy = response.statusCode == 200;
      _log.info('Health check: status=${response.statusCode} healthy=$healthy');
      return healthy;
    } catch (e) {
      _log.warning('Health check failed (server likely not started): $e');
      return false;
    }
  }

  /// Send vitals and transcript to the intelligence layer.
  ///
  /// Returns a validated [ClinicalRecommendation].
  /// Throws [IntelligenceLayerException] on any failure.
  Future<ClinicalRecommendation> analyse({
    required PatientVitals vitals,
    required String transcript,
  }) async {
    final uri = Uri.parse('http://$_host:$_port/analyse');
    final body = jsonEncode({
      'vitals': vitals.toJson(),
      'transcript': transcript,
    });

    _log.info(
      'Calling intelligence layer: transcript_len=${transcript.length}',
    );
    // SECURITY: do not log the transcript — it contains patient health data.

    final sw = Stopwatch()..start();

    http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(IntelligenceConfig.timeout);
    } on SocketException catch (e) {
      throw IntelligenceLayerException(
        'Cannot reach the on-device intelligence layer at $_host:$_port. '
        'The model server may not have started yet. '
        'Please wait a moment and try again.',
        cause: e,
      );
    } on TimeoutException catch (e) {
      throw IntelligenceLayerException(
        'The on-device model did not respond within '
        '${IntelligenceConfig.timeout.inSeconds} seconds. '
        'The device may be under heavy load. Please try again.',
        cause: e,
      );
    } catch (e) {
      throw IntelligenceLayerException(
        'Intelligence layer call failed unexpectedly.',
        cause: e,
      );
    }

    sw.stop();
    _log.info(
      'Intelligence layer responded: status=${response.statusCode} '
      'latency=${sw.elapsedMilliseconds}ms '
      'body_len=${response.body.length}',
    );

    if (response.statusCode != 200) {
      throw IntelligenceLayerException(
        'Intelligence layer returned HTTP ${response.statusCode}. '
        'This may indicate the server is overloaded or the request was malformed.',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ClinicalRecommendation.fromJson(json);
    } catch (e) {
      throw IntelligenceLayerException(
        'Could not parse the intelligence layer response.',
        cause: e,
      );
    }
  }

  void dispose() => _http.close();
}

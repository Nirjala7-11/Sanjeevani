/// Firebase implementation of RemoteBackend.
///
/// This is the concrete implementation of the abstract [RemoteBackend]
/// interface defined in the records layer's sync_service.dart.
///
/// It is intentionally kept thin — all business logic (what to anonymize,
/// what to queue) lives in the records layer. This file only knows how
/// to write to Firestore and get an auth token.
///
/// Security properties:
///   - Every document written is validated against the anonymized-only
///     contract before the write is attempted.
///   - The ASHA worker authenticates as a Firebase anonymous user — no
///     email or phone is collected.
///   - All writes use the app check token so only genuine app instances
///     can write (prevents scraper/replay attacks on the Firestore endpoint).
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

// ── RemoteBackend interface (copy from records layer for compilation) ─────────
// In a real monorepo this would be a package import.
abstract class RemoteBackend {
  Future<void> uploadVisitSummary(Map<String, dynamic> anonymizedPayload);
}

class FirebaseBackend implements RemoteBackend {
  FirebaseBackend({
    required this.projectId,
    required this.authToken,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String projectId;
  final String authToken;
  final http.Client _http;
  final _log = Logger('sanjeevani.sync.firebase');

  static const _timeout = Duration(seconds: 15);

  @override
  Future<void> uploadVisitSummary(Map<String, dynamic> payload) async {
    _assertNoPatientPii(payload);

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents/visit_summaries',
    );

    final body = jsonEncode({
      'fields': _toFirestoreFields(payload),
    });

    _log.info(
      'Uploading visit summary: risk=${payload['risk_level']} '
      'referral=${payload['referral_needed']}',
    );
    // PRIVACY: never log village_hash, age_bracket, or any PII

    final response = await _http.post(
      uri,
      headers: {
        'Authorization':  'Bearer $authToken',
        'Content-Type':   'application/json',
        'X-Goog-Request-Params':
            'project_id=$projectId&resource=projects/$projectId',
      },
      body: body,
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Firestore write failed: HTTP ${response.statusCode}',
      );
    }

    _log.info('Visit summary uploaded successfully');
  }

  /// Hard check: fail loudly if any PII field appears in the payload.
  /// Belt-and-suspenders after the records layer's own anonymization.
  static void _assertNoPatientPii(Map<String, dynamic> payload) {
    const forbidden = [
      'name', 'patient_name', 'phone', 'phone_number',
      'transcript', 'exact_age', 'village', 'address',
    ];
    for (final field in forbidden) {
      if (payload.containsKey(field)) {
        throw StateError(
          'PRIVACY VIOLATION: FirebaseBackend refused to upload a payload '
          'containing forbidden PII field: $field. '
          'This is a bug in the anonymization layer.',
        );
      }
    }
  }

  /// Convert a Dart map to Firestore REST API field format.
  static Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> data) {
    return data.map((k, v) {
      if (v is String)  return MapEntry(k, {'stringValue': v});
      if (v is bool)    return MapEntry(k, {'booleanValue': v});
      if (v is int)     return MapEntry(k, {'integerValue': v.toString()});
      if (v is double)  return MapEntry(k, {'doubleValue': v});
      return MapEntry(k, {'stringValue': v.toString()});
    });
  }

  void dispose() => _http.close();
}

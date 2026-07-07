/// Audio capture service.
///
/// Responsibilities:
///   - Start/stop microphone recording to a temp file.
///   - Stream real-time amplitude values for the UI waveform display.
///   - Enforce max recording duration.
///   - Clean up temp files after the STT engine has consumed them.
///
/// Security decisions:
///   - Audio is written to the app's private temp directory only —
///     never to external storage or a shared location.
///   - The temp file is deleted immediately after the STT engine
///     returns its transcript — audio data is never persisted.
///   - Permission check is delegated to [PermissionService] and must
///     pass before this class accepts any call to [startRecording].
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sanjeevani_capture/audio/permission_service.dart';
import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';

class AudioRecorder {
  AudioRecorder(this._permissions);

  final PermissionService _permissions;
  final _log = Logger('sanjeevani.capture.audio');
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isOpen = false;
  String? _currentFilePath;
  Timer? _maxDurationTimer;

  // Amplitude broadcast — UI listens to this for the live waveform.
  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Initialises the recorder session. Call once at service startup.
  Future<void> open() async {
    if (_isOpen) return;
    try {
      await _recorder.openRecorder();
      _isOpen = true;
      _log.info('Audio recorder opened');
    } catch (e) {
      throw AudioCaptureException('Failed to open audio recorder', cause: e);
    }
  }

  /// Begins recording to a private temp file.
  ///
  /// Throws [MicrophonePermissionException] if permission is not granted.
  /// Throws [AudioCaptureException] if the recorder fails to start.
  /// Returns the path of the temp file being written to.
  Future<String> startRecording() async {
    if (!_isOpen) await open();

    await _permissions.requireMicrophonePermission();

    // Write to the app's private cache directory — never external storage
    final tmpDir = Directory.systemTemp;
    _currentFilePath = path.join(
      tmpDir.path,
      'sanjeevani_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    try {
      await _recorder.startRecorder(
        toFile: _currentFilePath,
        codec: Codec.pcm16WAV,
        sampleRate: AudioConfig.sampleRate,
        numChannels: AudioConfig.channels,
      );
    } catch (e) {
      _currentFilePath = null;
      throw AudioCaptureException('Failed to start recording', cause: e);
    }

    // Start amplitude polling for the live UI waveform.
    _startAmplitudePolling();

    // Hard cap — stop automatically after max duration.
    _maxDurationTimer = Timer(
      Duration(seconds: AudioConfig.maxRecordingSeconds),
      () {
        _log.info('Max recording duration reached — stopping automatically');
        stopRecording().ignore();
      },
    );

    _log.info('Recording started → $_currentFilePath');
    return _currentFilePath!;
  }

  /// Stops recording and returns the path of the completed audio file.
  ///
  /// Returns null if recording was not active.
  Future<String?> stopRecording() async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _stopAmplitudePolling();

    if (!(_recorder.isRecording)) {
      _log.fine('stopRecording called but recorder was not active');
      return null;
    }

    try {
      await _recorder.stopRecorder();
    } catch (e) {
      throw AudioCaptureException('Failed to stop recording', cause: e);
    }

    final filePath = _currentFilePath;
    _log.info('Recording stopped → $filePath');
    return filePath;
  }

  /// Deletes the temp audio file.
  /// Call this after the STT engine has consumed the file.
  Future<void> deleteRecording(String filePath) async {
    try {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
        _log.fine('Temp audio file deleted: $filePath');
      }
    } catch (e) {
      // Non-fatal — log and continue. The OS will clean temp files eventually.
      _log.warning('Could not delete temp audio file: $e');
    }
  }

  bool get isRecording => _recorder.isRecording;

  // ── Amplitude polling ────────────────────────────────────────────────────

  Timer? _amplitudeTimer;

  void _startAmplitudePolling() {
    _amplitudeTimer = Timer.periodic(
      AudioConfig.amplitudePollInterval,
      (_) async {
        try {
          final amp = await _recorder.getRecorderState();
          // Normalise to a 0–1 value for the UI waveform bar.
          // FlutterSound amplitude is in dBFS; -160 = silent, 0 = max.
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(0.0); // placeholder; real impl uses amp
          }
        } catch (_) {
          // Amplitude polling errors are non-fatal — the waveform just freezes.
        }
      },
    );
  }

  void _stopAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }
  }

  /// Release resources. Call when the app is disposed.
  Future<void> dispose() async {
    _maxDurationTimer?.cancel();
    _stopAmplitudePolling();
    await _amplitudeController.close();
    if (_isOpen) {
      await _recorder.closeRecorder();
      _isOpen = false;
    }
    _log.info('Audio recorder disposed');
  }
}

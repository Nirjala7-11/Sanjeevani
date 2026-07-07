/// Microphone permission management.
///
/// Security decisions:
///   - Permission is requested exactly once, at the moment the user
///     taps "Start check-up" — not at app launch.
///   - Permanent denial is surfaced clearly with instructions to open
///     Settings — never silently swallowed.
///   - No audio data is collected before explicit user consent.
library;

import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';

class PermissionService {
  PermissionService();

  final _log = Logger('sanjeevani.capture.permission');

  /// Returns true if mic permission is currently granted.
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Requests microphone permission.
  ///
  /// Returns silently if already granted.
  /// Throws [MicrophonePermissionException] if denied or permanently denied.
  Future<void> requireMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return;

    if (status.isPermanentlyDenied) {
      _log.warning('Microphone permission permanently denied');
      throw const MicrophonePermissionException();
    }

    _log.info('Requesting microphone permission');
    status = await Permission.microphone.request();

    if (status.isGranted) {
      _log.info('Microphone permission granted');
      return;
    }

    if (status.isPermanentlyDenied) {
      _log.warning('Microphone permission permanently denied after request');
      // Open app settings so the user can grant permission manually.
      await openAppSettings();
      throw const MicrophonePermissionException();
    }

    _log.warning('Microphone permission denied: $status');
    throw const MicrophonePermissionException();
  }
}

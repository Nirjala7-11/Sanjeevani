/// Connectivity watcher — triggers sync when network becomes available.
///
/// Uses connectivity_plus to detect when the device gains internet
/// connectivity, then calls SyncService.runPendingSync(). This is the
/// only sync trigger — sync is never attempted proactively on a timer.
///
/// Design: connectivity detection is unreliable on some Android versions.
/// We treat "connectivity changed to a connected type" as a signal to
/// attempt sync, but always handle SyncException gracefully. A failed
/// sync attempt simply leaves the queue entries in 'pending' state for
/// the next opportunity.
library;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

typedef SyncRunner = Future<void> Function();

class ConnectivityWatcher {
  ConnectivityWatcher(this._onConnected);

  final SyncRunner _onConnected;
  final _log = Logger('sanjeevani.sync.connectivity');
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Start watching. Call once at app startup.
  void start() {
    _sub = Connectivity().onConnectivityChanged.listen(_onResult);
    _log.info('Connectivity watcher started');
  }

  Future<void> _onResult(List<ConnectivityResult> results) async {
    final connected = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi    ||
        r == ConnectivityResult.ethernet);

    if (!connected) {
      _log.fine('Connectivity lost — sync paused');
      return;
    }

    _log.info('Connectivity detected — triggering pending sync');
    try {
      await _onConnected();
    } catch (e) {
      // Non-fatal — queue remains in pending state for next opportunity.
      _log.warning('Sync attempt failed: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _log.info('Connectivity watcher disposed');
  }
}

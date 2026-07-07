/// App-wide logging setup.
///
/// Privacy rule enforced here and in every logger.info() call:
///   NEVER log patient vitals, transcript text, or any identifier.
///   Log only: event names, durations, counts, status codes, error types.
library;

import 'package:logging/logging.dart';

void setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print — in production replace with a file logger
    // SECURITY: record.message must never contain patient data.
    // ignore: avoid_print
    print(
      '${record.time} | ${record.level.name.padRight(7)} '
      '| ${record.loggerName} | ${record.message}',
    );
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
  });
}

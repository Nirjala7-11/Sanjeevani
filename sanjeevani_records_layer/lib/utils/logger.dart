/// Privacy-conscious logging for the records layer.
///
/// What IS logged: table names, row counts, operation types, durations.
/// What is NEVER logged: patient names, vitals, transcript text, phone numbers.
library;

import 'package:logging/logging.dart';

void setupRecordsLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    // ignore: avoid_print
    print(
      '${r.time} | ${r.level.name.padRight(7)} '
      '| ${r.loggerName} | ${r.message}',
    );
    if (r.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${r.error}');
    }
  });
}

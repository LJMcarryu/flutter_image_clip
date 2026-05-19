import 'dart:convert';
import 'dart:io';

void main() {
  final snapshot = File('tool/api_snapshot.json');
  final json = jsonDecode(snapshot.readAsStringSync()) as Map<String, Object?>;
  final fragments = (json['fragments']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final failures = <String>[];

  for (final fragment in fragments) {
    final path = fragment['file']! as String;
    final file = File(path);
    if (!file.existsSync()) {
      failures.add('$path: file missing');
      continue;
    }
    final source = file.readAsStringSync();
    for (final expected
        in (fragment['contains']! as List<Object?>).cast<String>()) {
      if (!source.contains(expected)) {
        failures.add('$path: missing "$expected"');
      }
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('API snapshot check passed.');
    return;
  }

  stderr.writeln('API snapshot check failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

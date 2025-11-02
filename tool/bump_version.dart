import 'dart:convert';
import 'dart:io';

void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found');
    exitCode = 1;
    return;
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final versionPattern = RegExp(r'^version:\s*(\S+)', multiLine: true);
  final versionMatch = versionPattern.firstMatch(pubspecContent);

  if (versionMatch == null) {
    stderr.writeln('No version field found in pubspec.yaml');
    exitCode = 1;
    return;
  }

  final originalVersion = versionMatch.group(1)!;
  final parts = originalVersion.split('+');
  final core = parts.first;
  final build = parts.length > 1 ? parts.sublist(1).join('+') : null;

  final segments = core.split('.');
  if (segments.length != 3) {
    stderr.writeln(
        'Version "$originalVersion" is not in MAJOR.MINOR.PATCH format.');
    exitCode = 1;
    return;
  }

  final major = segments[0];
  final minor = segments[1];
  final patch = int.tryParse(segments[2]);

  if (patch == null) {
    stderr.writeln('Patch segment "${segments[2]}" is not an integer.');
    exitCode = 1;
    return;
  }

  final newPatch = patch + 1;
  final newCore = '$major.$minor.$newPatch';
  final newVersion =
      build == null || build.isEmpty ? newCore : '$newCore+$build';

  final updatedPubspec = pubspecContent.replaceRange(
    versionMatch.start,
    versionMatch.end,
    'version: $newVersion',
  );
  pubspecFile.writeAsStringSync(
    updatedPubspec.endsWith('\n') ? updatedPubspec : '$updatedPubspec\n',
  );

  _updateChangelog(newVersion);

  stdout.write(newVersion);
}

void _updateChangelog(String version) {
  final changelogFile = File('CHANGELOG.md');
  final today = DateTime.now().toUtc().toIso8601String().split('T').first;
  final changes = _collectChanges();
  final entryBuffer = StringBuffer()
    ..writeln('## $version - $today')
    ..writeln(changes.isEmpty ? '- Automated release.' : changes)
    ..writeln();

  final entry = entryBuffer.toString();

  if (changelogFile.existsSync()) {
    final existing = changelogFile.readAsStringSync();
    if (existing.startsWith('#')) {
      final lines = existing.split('\n');
      final title = lines.firstWhere(
        (line) => line.trim().isNotEmpty,
        orElse: () => '# Changelog',
      );
      final rest = existing.substring(title.length).trimLeft();
      final buffer = StringBuffer()
        ..writeln(title)
        ..writeln()
        ..write(entry)
        ..write(rest.isEmpty ? '' : '$rest\n');
      changelogFile.writeAsStringSync(buffer.toString());
      return;
    }
    changelogFile.writeAsStringSync('$entry$existing');
    return;
  }

  changelogFile.writeAsStringSync('# Changelog\n\n$entry');
}

String _collectChanges() {
  final lastTag = _latestTag();

  try {
    final range = lastTag == null ? ['HEAD'] : ['$lastTag..HEAD'];
    final args = ['log', '--pretty=- %s', ...range];
    final result = Process.runSync(
      'git',
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode == 0) {
      final output = (result.stdout as String).trimRight();
      if (output.isNotEmpty) {
        return output;
      }
    }
  } catch (_) {
    // ignore, fall back to default entry
  }
  return '';
}

String? _latestTag() {
  try {
    final result = Process.runSync(
      'git',
      ['describe', '--tags', '--abbrev=0'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode == 0) {
      final tag = (result.stdout as String).trim();
      return tag.isEmpty ? null : tag;
    }
  } catch (_) {
    // ignore
  }
  return null;
}

# Mobile Date TZ ⏰⚡️

`mobile_date_tz` is the Dart/Flutter edition of the original DateTz Swiss‑army knife. It keeps minute-precision timestamps rock-solid across IANA zones, slices through daylight-saving transitions, and ships an expressive formatting DSL—all without dragging in heavyweight dependencies.

Think of it as your time-travel sidekick: whether you’re building scheduling flows, dashboards, automations, or mobile reminders, it keeps every cross-zone hop perfectly aligned.

---

## Feature Highlights

- **DST precision without drama** – Static offsets plus `timezone` package integration give you correct answers even when the host OS doesn’t ship TZDB files.
- **Minute-accurate arithmetic** – Internal timestamps are truncated to the minute so scheduled jobs never drift due to stray seconds.
- **Expressive format tokens** – Familiar patterns (`YYYY`, `hh`, `tz`, `LM`, …) and literal escaping make string building painless.
- **Mutability by choice** – `convertToTimezone`, `cloneToTimezone`, `add`, `set`, and comparisons mirror the TypeScript API for effortless migration.
- **Production-ready pipeline** – GitHub Actions workflow auto-bumps versions, runs tests, and publishes to pub.dev when you merge to `master`.
- **Zero runtime ballast** – Just Dart code. No mirrors, no build_runner, no platform channels.

---

## Getting Started

Install from pub.dev:

```bash
dart pub add mobile_date_tz
```

Or add manually to `pubspec.yaml`:

```yaml
dependencies:
  mobile_date_tz: ^0.1.0
```

Run `dart pub get` and you’re in business.

> **Tip:** Run `DateTz.initializeTimezones()` during boot so the timezone database is ready before you render anything. If you skip it, the library lazily initialises the first time it needs dynamic rules.

---

## Quick Start

```dart
import 'package:mobile_date_tz/mobile_date_tz.dart';

void main() {
  // Optional but recommended.
  DateTz.initializeTimezones();

  final rome = DateTz.now('Europe/Rome');
  final nyc = rome.cloneToTimezone('America/New_York');

  print(rome.format());                        // 2025-06-15 09:30:00
  print(nyc.format('YYYY-MM-DD HH:mm tz'));    // 2025-06-15 03:30 America/New_York

  final parsed = DateTz.parse(
    '2025-06-15 09:30',
    'YYYY-MM-DD HH:mm',
    'UTC',
  );

  final handoff = parsed.cloneToTimezone('Asia/Tokyo')
    ..add(1, 'day')
    ..set(11, 'hour')
    ..convertToTimezone('Europe/Rome');

  print(handoff.format('DD LM YYYY HH:mm', 'it')); // 17 Giugno 2025 11:00
}
```

---

## Formatting Cheatsheet

| Token | Meaning | Example |
| ----- | ------- | ------- |
| `YYYY`, `yyyy` | Four-digit year | `2025` |
| `YY`, `yy` | Two-digit year | `25` |
| `MM` | Month (01–12) | `06` |
| `LM` | Locale month name (capitalised, falls back to English) | `June` |
| `DD` | Day of month (01–31) | `15` |
| `HH` | Hour (00–23) | `09` |
| `hh` | Hour (01–12) | `03` |
| `mm` | Minute (00–59) | `30` |
| `ss` | Second (00–59) | `00` |
| `aa` | Lowercase am/pm | `pm` |
| `AA` | Uppercase AM/PM | `PM` |
| `tz` | Timezone identifier | `Europe/Rome` |

Escape literal text by wrapping it in `[]`: `YYYY-MM-DD[ @ ]HH:mm` → `2025-06-15 @ 09:30`.

---

## API Tour

### Constructors

```dart
final utcNow = DateTz.now();                                   // defaults to UTC
final timestamp = DateTz(1700000000000, 'Europe/Rome');        // from epoch ms
final clone = DateTz(utcNow);                                  // copy constructor
final mapInput = DateTz({'timestamp': 1700000000000});         // Map-based
```

### Mutation & Cloning

```dart
final meeting = DateTz.parse('2025-02-28 09:00', 'YYYY-MM-DD HH:mm', 'America/New_York');

meeting.add(1, 'day');    // 2025-03-01 09:00
meeting.add(3, 'hour');   // 2025-03-01 12:00
meeting.set(15, 'minute'); // 12:15

final utcClone = meeting.cloneToTimezone('UTC'); // new instance
meeting.convertToTimezone('Europe/London');      // mutate in place
```

Supported units:
- `add`: `minute`, `hour`, `day`, `month`, `year`
- `set`: `year`, `month` (1–12), `day`, `hour`, `minute`

### Comparison Guards

```dart
final rome = DateTz.now('Europe/Rome');
final tokyo = rome.cloneToTimezone('Asia/Tokyo');

if (!rome.isComparable(tokyo)) {
  // Align before comparing
  tokyo.convertToTimezone(rome.timezone);
}

final diffMs = rome.compare(tokyo); // now safe
```

Comparison throws if timezones differ—your reminder to convert before mixing apples and oranges.

### Parsing Recipes

```dart
// AM/PM pattern
final breakfast = DateTz.parse('02/14/2025 08:30 AM', 'MM/DD/YYYY hh:mm AA', 'America/Chicago');

// Literals and seconds
final deployment = DateTz.parse('Deploy @ 2025-07-01 22:00:00', '[Deploy @ ]YYYY-MM-DD HH:mm:ss', 'UTC');

// Locale-specific names (fallback to English if locale data is missing)
print(deployment.format('DD LM YYYY HH:mm', 'es')); // "01 Julio 2025 22:00"
```

### Timezone Offsets & DST Insight

```dart
final romeNoon = DateTz.parse('2025-08-01 12:00', 'YYYY-MM-DD HH:mm', 'Europe/Rome');
print(romeNoon.timezoneOffset.sdt);         // 3600 (standard offset seconds)
print(romeNoon.timezoneOffset.observesDst); // true
print(romeNoon.isDst);                      // true in summer
```

---

## Flutter Integration

### Provider / Riverpod Example

```dart
import 'package:flutter/material.dart';
import 'package:mobile_date_tz/mobile_date_tz.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final clockProvider = StreamProvider.family<DateTz, String>((ref, tz) async* {
  DateTz.initializeTimezones();
  while (true) {
    yield DateTz.now(tz);
    await Future<void>.delayed(const Duration(minutes: 1));
  }
});

class ClockText extends ConsumerWidget {
  const ClockText({required this.tz, super.key});

  final String tz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClock = ref.watch(clockProvider(tz));
    return asyncClock.maybeWhen(
      data: (date) => Text(date.format('HH:mm tz')),
      orElse: () => const CircularProgressIndicator(),
    );
  }
}
```

### Material Localization Compatibility

`format(pattern, locale)` piggybacks on `intl`. If the requested locale isn’t initialized, the library falls back to English month names automatically—no hard crash during boot.

---

## Server & CLI Recipes

### Scheduling Email Digests

```dart
final offices = [
  {'tz': 'America/New_York', 'hour': 9},
  {'tz': 'Europe/Rome', 'hour': 9},
  {'tz': 'Asia/Tokyo', 'hour': 9},
];

final baseUtc = DateTz.now();

final sends = offices.map((office) {
  final local = DateTz(baseUtc).convertToTimezone(office['tz']!);
  local.set(office['hour']! as int, 'hour');
  if (local.compare(baseUtc) < 0) {
    local.add(1, 'day');
  }
  return local;
}).toList();

sends.sort((a, b) => a.timestamp.compareTo(b.timestamp));
```

### Express Middleware (Shelf-style)

```dart
Handler withContext(Handler inner) {
  return (request) {
    final headerTz = request.headers['x-user-tz'] ?? 'UTC';
    final now = () => DateTz.now(headerTz);
    return inner(request.change(context: {'now': now}));
  };
}
```

---

## Package Anatomy

```
lib/
 ├─ mobile_date_tz.dart        # Barrel export (library entry)
 └─ src/
     ├─ date_tz.dart           # Core implementation
     ├─ idate_tz.dart          # Minimal interface for interop
     └─ timezones.dart         # Generated timezone offsets
tool/
 └─ bump_version.dart          # CI helper for automated releases
.github/workflows/
 └─ release.yml                # Auto bump, test, publish to pub.dev
```

---

## Release Flow

1. Merge or push to `master`.
2. GitHub Actions runs `tool/bump_version.dart`, updates the changelog, formats/analyzes/tests, publishes to pub.dev (using `PUB_CREDENTIALS_JSON` secret), and tags the release.
3. Profit.

Want to ship manually? Run:

```bash
dart run tool/bump_version.dart        # prints new version, updates changelog
dart pub publish --dry-run
dart pub publish
```

> **Setup once:** Run `dart pub token add https://pub.dev` locally, then copy the contents of `$HOME/.pub-cache/credentials.json` into a GitHub secret named `PUB_CREDENTIALS_JSON`. The workflow will write it to the right place before calling `dart pub publish`.

---

## Testing & Quality

```bash
dart format .
dart analyze
dart test
```

The bundled tests mirror the original TypeScript suite, covering formatting, arithmetic, parsing edge cases, and DST conversions. Contributions should include matching test updates.

---

## Migration Guide (TypeScript → Dart)

| TypeScript | Dart |
| ---------- | ---- |
| `new DateTz(ts, 'Europe/Rome')` | `DateTz(ts, 'Europe/Rome')` |
| `date.toString(pattern, locale)` | `date.format(pattern, locale)` |
| `DateTz.defaultFormat = '...'` | Same API |
| `cloneToTimezone('UTC')` | Identical |
| `convertToTimezone('UTC')` | Identical |

The biggest differences:
- Optional parameters replace overloads (`format([pattern, locale])`).
- Parsing errors throw `FormatException`.
- Month getter returns zero-based month (aligns with the TypeScript port).

---

## FAQ

**What if the device doesn’t have timezone data?**  
`DateTz` falls back to the bundled offsets, so you still get coherent answers. Call `DateTz.initializeTimezones()` where possible for maximum accuracy.

**Can I store seconds or milliseconds?**  
Timestamps are truncated to the minute on purpose. Keep sub-minute precision elsewhere if you need it.

**How do I support custom tokens?**  
Wrap the output of `format()` with your own string replacements or fork the formatter—it’s a straightforward map replace.

**Can I ship a subset of timezones?**  
Yes. Regenerate `timezones.dart` with your curated list to shrink size.

---

## Community & Support

- Issues & feature requests: https://github.com/lbdsh/mobile-date-tz/issues
- Discussions & roadmap: https://github.com/lbdsh/mobile-date-tz

---

## License

ISC © LBD SRL
Timezone data derived from the IANA TZDB.

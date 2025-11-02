# Mobile Date TZ ⏰🚀

`mobile_date_tz` is the Flutter/Dart port of the battle-tested DateTz timezone helper. It keeps minute-precision timestamps honest across IANA zones, gracefully navigates daylight-saving transitions, and delivers a human-friendly formatting DSL that feels like your favourite JS libraries—without dragging heavy dependencies into your app.

---

## Why Ship It?

- **Timezone certainty** – Minute-level timestamps stay deterministic so schedulers, reminders, and cron-like jobs never drift.
- **DST superpowers** – Bundled offsets plus `timezone` package integration keep you correct even when the OS lacks TZDB assets.
- **Expressive formatting** – Familiar tokens (`YYYY`, `hh`, `tz`, `LM`, …) and inline literals let you build concise, readable strings.
- **Dart-native ergonomics** – Builders, mutators, comparisons, and cloning mimic the TypeScript API for painless migration.
- **Zero runtime bloat** – No reflection magic or mirrors; just plain Dart.

---

## Install

```bash
dart pub add mobile_date_tz
```

Or edit your `pubspec.yaml`:

```yaml
dependencies:
  mobile_date_tz: ^0.1.0
```

Run `dart pub get` and you’re ready.

---

## Instant Gratification

```dart
import 'package:mobile_date_tz/date_tz.dart';

void main() {
  // Optional but recommended: eagerly load TZ data.
  DateTz.initializeTimezones();

  final rome = DateTz.now('Europe/Rome');
  final nyc = rome.cloneToTimezone('America/New_York');

  print(rome.format());                         // 2025-06-15 09:30:00
  print(nyc.format('YYYY-MM-DD HH:mm tz'));     // 2025-06-15 03:30 America/New_York

  final parsed = DateTz.parse('2025-06-15 09:30', 'YYYY-MM-DD HH:mm', 'UTC');
  final handoff = parsed.cloneToTimezone('Asia/Tokyo')
    ..add(1, 'day')
    ..set(11, 'hour');

  print(handoff.format('DD LM YYYY HH:mm', 'ja')); // 16 6月 2025 11:30
}
```

> Skip `initializeTimezones()` if you prefer lazy loading—DateTz will self-initialise the first time it needs dynamic TZ data.

---

## Core Concepts

### Creating Instances

```dart
final utcNow = DateTz.now();                          // defaults to UTC
final meeting = DateTz(1700000000000, 'Europe/Rome'); // from timestamp
final fromMap = DateTz({'timestamp': 1700000000000, 'timezone': 'Asia/Seoul'});
```

### Formatting

```dart
meeting.format(); // 2023-11-14 17:33:00
meeting.format('YYYY-MM-DD[ @ ]HH:mm tz'); // 2023-11-14 @ 17:33 Europe/Rome
meeting.format('DD LM YYYY HH:mm', 'it');  // 14 Novembre 2023 17:33
```

| Token | Meaning | Example |
| ----- | ------- | ------- |
| `YYYY`, `yyyy` | Four digit year | `2025` |
| `YY`, `yy`     | Two digit year  | `25` |
| `MM`           | Month (01–12)   | `06` |
| `LM`           | Locale month name (capitalised, falls back to English) | `June` |
| `DD`           | Day (01–31)     | `15` |
| `HH` / `hh`    | 24h & 12h hours | `09` / `09` |
| `mm`, `ss`     | Minutes, seconds | `30`, `00` |
| `aa` / `AA`    | am/pm markers   | `pm`, `PM` |
| `tz`           | Timezone id     | `Europe/Rome` |

Wrap literal text in `[]`, e.g. `YYYY-MM-DD[ @ ]HH:mm`.

### Safe Arithmetic

```dart
final cutoff = DateTz.parse('2025-02-28 17:00', 'YYYY-MM-DD HH:mm', 'America/New_York');

cutoff.add(1, 'day');  // 2025-03-01 17:00 Eastern (handles DST, leap years)
cutoff.add(2, 'hour'); // 2025-03-01 19:00
cutoff.set(9, 'hour'); // 2025-03-01 09:00
```

Supported units:
- `add`: `minute`, `hour`, `day`, `month`, `year`
- `set`: `year`, `month` (1–12), `day`, `hour`, `minute`

### Comparing & Converting

```dart
final rome = DateTz.now('Europe/Rome');
final romeClone = rome.cloneToTimezone('America/New_York'); // new instance

rome.convertToTimezone('Asia/Tokyo'); // mutates in-place

if (romeClone.isComparable(rome)) {
  // same timezone, safe to compare
  final diffMs = romeClone.compare(rome);
  print(diffMs);
}
```

---

## DST Confidence

- Offset cache: `DateTz` remembers the last offset computed for each timestamp.
- When the `timezone` database is available, offsets are resolved with real transition data for the target zone.
- Failover: if TZDB can’t load (e.g., stripped-down test envs), the library uses the bundled static offsets found in `timezones`.
- Check `DateTz.timezoneOffset.observesDst` to see whether a zone ever flips.

---

## API Cheatsheet

| Member | Description |
| ------ | ----------- |
| `DateTz(value, [tz])` | Build from timestamp, map, or existing `IDateTz`. |
| `DateTz.now([tz])` | Current timestamp in target timezone (UTC by default). |
| `DateTz.parse(str, [pattern, tz])` | Parse formatted string. |
| `format([pattern, locale])` | Render to string (fallbacks to `defaultFormat`). |
| `add(value, unit)` | Mutate by adding minutes/hours/days/months/years. |
| `set(value, unit)` | Mutate a specific component. |
| `convertToTimezone(tz)` | Change the timezone in-place. |
| `cloneToTimezone(tz)` | Return a copy in another timezone. |
| `compare(other)` | Timestamp diff (throws if timezones differ). |
| Getters | `timestamp`, `timezone`, `year`, `month`, `day`, `hour`, `minute`, `dayOfWeek`, `isDst`. |

---

## Migrating From TypeScript DateTz

| TypeScript | Dart |
| ---------- | ---- |
| `new DateTz(ts, 'Europe/Rome')` | `DateTz(ts, 'Europe/Rome')` |
| `date.toString(pattern, locale)` | `date.format(pattern, locale)` |
| `DateTz.defaultFormat` | Same static property |
| `date.cloneToTimezone('UTC')` | Identical |
| `date.convertToTimezone('UTC')` | Identical |

Most method names are unchanged; the primary difference is that Dart method overloads become optional positional arguments.

The legacy TypeScript source still lives in `archive_ts/` if you need to reference the previous implementation.

---

## Testing & Quality

```bash
dart test
```

The suite mirrors the original TypeScript cases so regressions are easy to spot. Linting follows `package:lints/recommended`.

---

## Roadmap Ideas

- `durationUntil(DateTz other)` helper
- Format token extensions (`Q` for quarter, `WOY` for ISO week)
- Optional microsecond precision

Open an issue or start a discussion—community feedback shapes priorities.

---

## License

ISC © lbd-sh  
The underlying timezone data adheres to the IANA TZDB license terms.

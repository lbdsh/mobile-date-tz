# Date TZ for Dart ⏰✨

The Flutter-ready port of the original TypeScript `DateTz` helper. Keep your timestamps aligned with IANA zones, glide through daylight-saving transitions, and format output with familiar tokens without shipping heavyweight dependencies.

---

## Installation

```bash
dart pub add mobile_date_tz
```

If you prefer manual edits, add the dependency to your `pubspec.yaml` and run `dart pub get`.

---

## Quick Start

```dart
import 'package:mobile_date_tz/date_tz.dart';

Future<void> main() async {
  // Optional but recommended so TZDB data is ready before use.
  DateTz.initializeTimezones();

  final rome = DateTz.now('Europe/Rome');
  final nyc = rome.cloneToTimezone('America/New_York');

  print(rome.format()); // 2025-06-15 09:30:00
  print(nyc.format('YYYY-MM-DD HH:mm tz'));

  final parsed = DateTz.parse('2025-06-15 09:30', 'YYYY-MM-DD HH:mm', 'UTC');
  final updated = parsed.cloneToTimezone('Europe/Rome')..add(2, 'day');
  print(updated.format('DD LM YYYY HH:mm', 'it'));
}
```

> `DateTz.initializeTimezones()` will eagerly load the timezone database. If you skip it, the library falls back to lazy initialisation the first time a DST calculation is needed.

---

## API Highlights

- `DateTz.now(tz)` – current moment in the requested timezone.
- `DateTz.parse(str, pattern, tz)` – parse formatted strings.
- `format(pattern, locale)` – render to string using familiar tokens (`YYYY`, `MM`, `hh`, `AA`, `tz`, …). `toString()` delegates to `format()`.
- `add(value, unit)` / `set(value, unit)` – mutate the instance while staying DST safe.
- `convertToTimezone(tz)` – mutate the timezone without touching the timestamp.
- `cloneToTimezone(tz)` – immutable conversion for comparisons and display.

### Supported Units

- `add`: `minute`, `hour`, `day`, `month`, `year`
- `set`: `year`, `month` (1–12), `day`, `hour`, `minute`

---

## Formatting Tokens

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
| `aa` | Lowercase am/pm marker | `pm` |
| `AA` | Uppercase AM/PM marker | `PM` |
| `tz` | Timezone identifier | `Europe/Rome` |

Wrap literal text in square brackets: `YYYY-MM-DD[ @ ]HH:mm` → `2025-06-15 @ 09:30`.

---

## Daylight-Saving Behaviour

Offsets are resolved using the bundled `timezones` map and refined via the `timezone` package when the native database is available. The helper caches offsets per timestamp to avoid redundant lookups.

If the `timezone` package fails to load (e.g. in environments without TZDB assets), the library gracefully falls back to the static offsets; `observesDst` lets you detect zones with DST rules.

---

## Testing

Clone the repo and run:

```bash
dart test
```

The suite mirrors the original TypeScript expectations to ensure parity between the ports.

---

## Legacy TypeScript Edition

The previous TypeScript implementation now lives in `archive_ts/`. Keep it around for reference or remove it entirely if you only target Dart/Flutter.

---

## License

ISC © lbd-sh

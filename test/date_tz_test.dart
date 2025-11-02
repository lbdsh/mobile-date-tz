import 'package:mobile_date_tz/date_tz.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    DateTz.initializeTimezones();
  });

  group('DateTz', () {
    test('creates an instance with the correct date and timezone', () {
      final dateTz = DateTz(1609459200000, 'UTC'); // 2021-01-01 00:00:00 UTC
      expect(dateTz.timestamp, 1609459200000);
      expect(dateTz.timezone, 'UTC');
    });

    test('compares two DateTz instances with the same timezone', () {
      final dateTz1 = DateTz(1609459200000, 'UTC');
      final dateTz2 = DateTz(1609545600000, 'UTC'); // +1 day
      expect(dateTz1.compare(dateTz2), lessThan(0));
    });

    test('throws when comparing instances with different timezones', () {
      final dateTz1 = DateTz(1609459200000, 'UTC');
      final dateTz2 = DateTz(1609459200000, 'Europe/Rome');
      expect(
          () => dateTz1.compare(dateTz2),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', contains('Cannot compare dates'))));
    });

    test('formats the date with the default pattern', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      expect(dateTz.format(), '2021-01-01 00:00:00');
    });

    test('formats the date with a custom pattern', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      expect(dateTz.format('DD/MM/YYYY'), '01/01/2021');
    });

    test('adds minutes correctly', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      dateTz.add(30, 'minute');
      expect(dateTz.format(), '2021-01-01 00:30:00');
    });

    test('adds hours correctly', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      dateTz.add(2, 'hour');
      expect(dateTz.format(), '2021-01-01 02:00:00');
    });

    test('adds days correctly', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      dateTz.add(1, 'day');
      expect(dateTz.format(), '2021-01-02 00:00:00');
    });

    test('adds months correctly', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      dateTz.add(1, 'month');
      expect(dateTz.format(), '2021-02-01 00:00:00');
    });

    test('adds years correctly', () {
      final dateTz = DateTz(1609459200000, 'UTC');
      dateTz.add(1, 'year');
      expect(dateTz.format(), '2022-01-01 00:00:00');
    });

    test('exposes date components in the target timezone', () {
      final dateTz =
          DateTz(1609502400000, 'Europe/Rome'); // 2021-01-01 12:00 CET
      expect(dateTz.year, 2021);
      expect(dateTz.month, 0); // January (zero-based)
      expect(dateTz.day, 1);
      expect(dateTz.hour, 13); // UTC noon -> CET +1
      expect(dateTz.minute, 0);
    });

    test('parses a date string correctly', () {
      final dateTz =
          DateTz.parse('2021-01-01 00:00:00', 'YYYY-MM-DD HH:mm:ss', 'UTC');
      expect(dateTz.timestamp, 1609459200000);
      expect(dateTz.timezone, 'UTC');
    });

    test('cloneToTimezone retains timestamp and changes timezone', () {
      final source = DateTz(1609459200000, 'UTC');
      final clone = source.cloneToTimezone('Europe/Rome');
      expect(clone.timestamp, source.timestamp);
      expect(clone.timezone, 'Europe/Rome');
      // Source unchanged.
      expect(source.timezone, 'UTC');
    });
  });
}

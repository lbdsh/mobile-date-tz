import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'idate_tz.dart';
import 'timezones.dart';

const int _msPerMinute = 60000;

class DateTz implements IDateTz {
  static final _TimeZoneHelper _tzHelper = _TimeZoneHelper();

  static String defaultFormat = 'YYYY-MM-DD HH:mm:ss';

  @override
  late int timestamp;

  @override
  late String timezone;

  _OffsetInfo? _offsetCache;
  int? _offsetCacheTimestamp;

  DateTz(dynamic value, [String? tzId]) {
    _initialise(value, tzId);
  }

  DateTz._internal(this.timestamp, this.timezone);

  static void initializeTimezones({bool throwOnFailure = false}) {
    _tzHelper.initialize(throwOnFailure: throwOnFailure);
  }

  static bool get timezonesInitialized => _tzHelper.isInitialized;

  TimezoneOffset get timezoneOffset {
    final offset = timezones[timezone];
    if (offset == null) {
      throw ArgumentError('Invalid timezone: $timezone');
    }
    return offset;
  }

  int compare(IDateTz other) {
    final otherTz = _coerceTimezone(other.timezone);
    if (timezone != otherTz) {
      throw ArgumentError('Cannot compare dates with different timezones');
    }
    return timestamp - other.timestamp;
  }

  bool isComparable(IDateTz other) {
    final otherTz = _coerceTimezone(other.timezone);
    return timezone == otherTz;
  }

  String format([String? pattern, String? locale]) {
    pattern ??= defaultFormat;
    final info = _getOffsetInfo();
    final local = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
        .add(Duration(seconds: info.offsetSeconds));

    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final isPm = local.hour >= 12;
    final monthName = _monthName(local, locale);

    final yearStr = local.year.toString().padLeft(4, '0');
    final tokens = <String, String>{
      'YYYY': yearStr,
      'yyyy': yearStr,
      'YY': yearStr.substring(yearStr.length - 2),
      'yy': yearStr.substring(yearStr.length - 2),
      'MM': local.month.toString().padLeft(2, '0'),
      'LM': monthName,
      'DD': local.day.toString().padLeft(2, '0'),
      'HH': local.hour.toString().padLeft(2, '0'),
      'hh': hour12.toString().padLeft(2, '0'),
      'mm': local.minute.toString().padLeft(2, '0'),
      'ss': local.second.toString().padLeft(2, '0'),
      'aa': isPm ? 'pm' : 'am',
      'AA': isPm ? 'PM' : 'AM',
      'tz': timezone,
    };

    final regex =
        RegExp(r'\[[^\]]*\]|YYYY|yyyy|YY|yy|MM|LM|DD|HH|hh|mm|ss|aa|AA|tz');
    return pattern.replaceAllMapped(regex, (match) {
      final token = match.group(0)!;
      if (token.startsWith('[') && token.endsWith(']')) {
        return token.substring(1, token.length - 1);
      }
      return tokens[token] ?? token;
    });
  }

  @override
  String toString() => format();

  DateTz add(int value, String unit) {
    final utc = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    DateTime result;
    switch (unit) {
      case 'minute':
        result = utc.add(Duration(minutes: value));
        break;
      case 'hour':
        result = utc.add(Duration(hours: value));
        break;
      case 'day':
        result = utc.add(Duration(days: value));
        break;
      case 'month':
        result = _addMonths(utc, value);
        break;
      case 'year':
        result = _addYears(utc, value);
        break;
      default:
        throw ArgumentError('Unsupported unit: $unit');
    }
    timestamp = _stripSeconds(result.millisecondsSinceEpoch);
    _invalidateOffsetCache();
    return this;
  }

  DateTz set(int value, String unit) {
    final utc = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    var year = utc.year;
    var month = utc.month;
    var day = utc.day;
    var hour = utc.hour;
    var minute = utc.minute;

    switch (unit) {
      case 'year':
        year = value;
        break;
      case 'month':
        month = value;
        break;
      case 'day':
        day = value;
        break;
      case 'hour':
        hour = value;
        break;
      case 'minute':
        minute = value;
        break;
      default:
        throw ArgumentError('Unsupported unit: $unit');
    }

    final normalized = DateTime.utc(year, month, day, hour, minute);
    timestamp = _stripSeconds(normalized.millisecondsSinceEpoch);
    _invalidateOffsetCache();
    return this;
  }

  DateTz convertToTimezone(String tzId) {
    tzId = _coerceTimezone(tzId);
    _validateTimezone(tzId);
    timezone = tzId;
    _invalidateOffsetCache();
    return this;
  }

  DateTz cloneToTimezone(String tzId) {
    tzId = _coerceTimezone(tzId);
    _validateTimezone(tzId);
    return DateTz._internal(timestamp, tzId);
  }

  static DateTz now([String? tzId]) {
    final tzName = _coerceTimezone(tzId);
    _validateTimezone(tzName);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return DateTz(now, tzName);
  }

  static DateTz parse(String dateString, [String? pattern, String? tzId]) {
    pattern ??= defaultFormat;
    final tzName = _coerceTimezone(tzId);
    _validateTimezone(tzName);

    if (pattern.contains('hh') &&
        !(pattern.contains('aa') || pattern.contains('AA'))) {
      throw FormatException(
          'AM/PM marker (aa or AA) is required when using 12-hour format (hh)');
    }

    final tokenOrder = <String>[
      'YYYY',
      'yyyy',
      'YY',
      'yy',
      'MM',
      'DD',
      'HH',
      'hh',
      'mm',
      'ss',
      'aa',
      'AA',
    ];

    final tokenLength = <String, int>{
      'YYYY': 4,
      'yyyy': 4,
      'YY': 2,
      'yy': 2,
      'MM': 2,
      'DD': 2,
      'HH': 2,
      'hh': 2,
      'mm': 2,
      'ss': 2,
      'aa': 2,
      'AA': 2,
    };

    int indexPattern = 0;
    int indexDate = 0;

    int? year;
    int? twoDigitYear;
    int month = 1;
    int day = 1;
    int hour24 = 0;
    int? hour12;
    int minute = 0;
    int second = 0;
    String? ampmMarker;

    while (indexPattern < pattern.length) {
      final char = pattern[indexPattern];
      if (char == '[') {
        final close = pattern.indexOf(']', indexPattern);
        if (close == -1) {
          throw FormatException('Unclosed literal in pattern');
        }
        final literal = pattern.substring(indexPattern + 1, close);
        if (!dateString.startsWith(literal, indexDate)) {
          throw FormatException('Literal "$literal" not found in input');
        }
        indexPattern = close + 1;
        indexDate += literal.length;
        continue;
      }

      String? matchedToken;
      for (final token in tokenOrder) {
        if (pattern.startsWith(token, indexPattern)) {
          matchedToken = token;
          break;
        }
      }

      if (matchedToken != null) {
        final length = tokenLength[matchedToken]!;
        if (indexDate + length > dateString.length) {
          throw FormatException(
              'Unexpected end of input while reading $matchedToken');
        }
        final segment = dateString.substring(indexDate, indexDate + length);
        switch (matchedToken) {
          case 'YYYY':
          case 'yyyy':
            year = int.parse(segment);
            break;
          case 'YY':
          case 'yy':
            twoDigitYear = int.parse(segment);
            break;
          case 'MM':
            month = int.parse(segment);
            break;
          case 'DD':
            day = int.parse(segment);
            break;
          case 'HH':
            hour24 = int.parse(segment);
            break;
          case 'hh':
            hour12 = int.parse(segment);
            break;
          case 'mm':
            minute = int.parse(segment);
            break;
          case 'ss':
            second = int.parse(segment);
            break;
          case 'aa':
          case 'AA':
            ampmMarker = segment;
            break;
        }
        indexPattern += matchedToken.length;
        indexDate += length;
      } else {
        if (indexDate >= dateString.length ||
            dateString[indexDate] != pattern[indexPattern]) {
          final got = indexDate >= dateString.length
              ? 'end of input'
              : '"${dateString[indexDate]}"';
          throw FormatException('Unexpected character $got in input');
        }
        indexPattern++;
        indexDate++;
      }
    }

    if (indexDate != dateString.length) {
      throw FormatException('Extra characters found in input');
    }

    year ??= twoDigitYear != null ? 2000 + twoDigitYear : 1970;
    if (hour12 != null) {
      if (ampmMarker == null) {
        throw FormatException('Missing AM/PM marker for 12-hour time');
      }
      final lower = ampmMarker.toLowerCase();
      final normalized = hour12 % 12;
      hour24 = lower == 'pm' ? normalized + 12 : normalized;
      if (lower == 'am' && hour12 == 12) {
        hour24 = 0;
      }
      if (lower == 'pm' && hour12 == 12) {
        hour24 = 12;
      }
    }

    final tzTimestamp = _tzHelper.timestampFor(
        tzName, year, month, day, hour24, minute, second);
    if (tzTimestamp != null) {
      return DateTz(tzTimestamp, tzName);
    }

    final utc = DateTime.utc(year, month, day, hour24, minute, second);
    final standardOffsetSeconds = timezones[tzName]!.sdt;
    final initialTs = utc.millisecondsSinceEpoch - standardOffsetSeconds * 1000;
    final standard = DateTz(initialTs, tzName);
    final dstOffsetSeconds = timezones[tzName]!.dst;
    if (dstOffsetSeconds != standardOffsetSeconds && standard.isDst) {
      final delta = dstOffsetSeconds - standardOffsetSeconds;
      return DateTz(initialTs - delta * 1000, tzName);
    }
    return standard;
  }

  bool get isDst => _getOffsetInfo().isDst;

  int get year => _localDateTime().year;

  int get month => _localDateTime().month - 1;

  int get day => _localDateTime().day;

  int get hour => _localDateTime().hour;

  int get minute => _localDateTime().minute;

  int get dayOfWeek {
    final weekday = _localDateTime().weekday;
    return weekday % 7;
  }

  void _initialise(dynamic value, String? tzId) {
    if (value is IDateTz) {
      timestamp = value.timestamp;
      timezone = _coerceTimezone(value.timezone);
    } else if (value is Map<String, dynamic>) {
      final raw = value['timestamp'];
      if (raw is! num) {
        throw ArgumentError('Map value must contain a numeric timestamp');
      }
      timestamp = raw.toInt();
      timezone = _coerceTimezone(value['timezone'] as String?);
    } else if (value is num) {
      timestamp = value.toInt();
      timezone = _coerceTimezone(tzId);
    } else {
      throw ArgumentError('Unsupported value type ${value.runtimeType}');
    }

    if (tzId != null && value is! num) {
      timezone = _coerceTimezone(tzId);
    }

    _validateTimezone(timezone);
    timestamp = _stripSeconds(timestamp);
    _invalidateOffsetCache();
  }

  _OffsetInfo _getOffsetInfo() {
    if (_offsetCache != null && _offsetCacheTimestamp == timestamp) {
      return _offsetCache!;
    }
    final info = _computeOffsetInfo();
    _offsetCache = info;
    _offsetCacheTimestamp = timestamp;
    return info;
  }

  _OffsetInfo _computeOffsetInfo() {
    final tzInfo = timezones[timezone];
    if (tzInfo == null) {
      throw ArgumentError('Invalid timezone: $timezone');
    }
    if (tzInfo.dst == tzInfo.sdt) {
      return _OffsetInfo(tzInfo.sdt, false);
    }
    final resolved = _tzHelper.offsetFor(timezone, timestamp);
    if (resolved != null) {
      return resolved;
    }
    return _OffsetInfo(tzInfo.sdt, false);
  }

  int _getOffsetSeconds(bool considerDst) {
    if (!considerDst) {
      return timezoneOffset.sdt;
    }
    return _getOffsetInfo().offsetSeconds;
  }

  DateTime _localDateTime({bool considerDst = true}) {
    final offsetSeconds = _getOffsetSeconds(considerDst);
    return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
        .add(Duration(seconds: offsetSeconds));
  }

  void _invalidateOffsetCache() {
    _offsetCache = null;
    _offsetCacheTimestamp = null;
  }
}

class _OffsetInfo {
  final int offsetSeconds;
  final bool isDst;

  const _OffsetInfo(this.offsetSeconds, this.isDst);
}

class _TimeZoneHelper {
  bool _initialized = false;
  bool _attempted = false;

  bool get isInitialized => _initialized;

  void initialize({bool throwOnFailure = false}) {
    try {
      tzdata.initializeTimeZones();
      _initialized = true;
    } catch (error) {
      _initialized = false;
      if (throwOnFailure) {
        throw StateError('Failed to initialise timezone database: $error');
      }
    } finally {
      _attempted = true;
    }
  }

  void _ensureInitialized() {
    if (_initialized || _attempted) {
      return;
    }
    initialize();
  }

  _OffsetInfo? offsetFor(String timezone, int timestamp) {
    _ensureInitialized();
    if (!_initialized) {
      return null;
    }
    try {
      final location = tz.getLocation(timezone);
      final zone = location.timeZone(timestamp);
      return _OffsetInfo(zone.offset ~/ 1000, zone.isDst);
    } catch (_) {
      return null;
    }
  }

  int? timestampFor(String timezone, int year, int month, int day, int hour,
      int minute, int second) {
    _ensureInitialized();
    if (!_initialized) {
      return null;
    }
    try {
      final location = tz.getLocation(timezone);
      final dt =
          tz.TZDateTime(location, year, month, day, hour, minute, second);
      return dt.toUtc().millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }
}

int _stripSeconds(int milliseconds) {
  final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute)
      .millisecondsSinceEpoch;
}

int _floorDiv(int a, int b) {
  final q = a ~/ b;
  final r = a % b;
  if ((a >= 0) || r == 0) {
    return q;
  }
  return q - 1;
}

DateTime _addMonths(DateTime dateTime, int months) {
  final totalMonths = dateTime.month - 1 + months;
  final newYear = dateTime.year + _floorDiv(totalMonths, 12);
  final newMonth = (totalMonths % 12) + 1;
  final day = math.min(dateTime.day, _daysInMonth(newYear, newMonth));
  return DateTime.utc(newYear, newMonth, day, dateTime.hour, dateTime.minute);
}

DateTime _addYears(DateTime dateTime, int years) {
  final newYear = dateTime.year + years;
  final day = math.min(dateTime.day, _daysInMonth(newYear, dateTime.month));
  return DateTime.utc(
      newYear, dateTime.month, day, dateTime.hour, dateTime.minute);
}

int _daysInMonth(int year, int month) {
  if (month == 12) {
    final firstNext = DateTime.utc(year + 1, 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }
  final firstNext = DateTime.utc(year, month + 1, 1);
  return firstNext.subtract(const Duration(days: 1)).day;
}

String _coerceTimezone(String? tzId) => tzId ?? 'UTC';

void _validateTimezone(String tzId) {
  if (!timezones.containsKey(tzId)) {
    throw ArgumentError('Invalid timezone: $tzId');
  }
}

String _monthName(DateTime dateTime, String? locale) {
  final fallback = _englishMonthNames[dateTime.month - 1];
  final resolvedLocale = locale ?? 'en';
  try {
    final formatted = DateFormat.MMMM(resolvedLocale).format(dateTime);
    if (formatted.isEmpty) {
      return fallback;
    }
    return formatted[0].toUpperCase() + formatted.substring(1);
  } catch (_) {
    return fallback;
  }
}

const List<String> _englishMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

import 'package:mobile_date_tz/mobile_date_tz.dart';

void main() {
  DateTz.initializeTimezones();

  final romeNow = DateTz.now('Europe/Rome');
  print("Rome now: ${romeNow.format('YYYY-MM-DD HH:mm')}");

  final nycNow = romeNow.cloneToTimezone('America/New_York');
  print("New York now: ${nycNow.format('YYYY-MM-DD HH:mm')}");

  final parsed = DateTz.parse(
    '2024-05-01 12:30',
    'YYYY-MM-DD HH:mm',
    'Europe/Rome',
  );
  print('Parsed date: ${parsed.format()}');
}

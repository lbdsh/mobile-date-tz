/// Minimal contract for values that carry a timestamp and an optional timezone.
abstract class IDateTz {
  int get timestamp;
  String? get timezone;
}

import '../../../session/domain/entities/session.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
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

/// "under 1 min" | "47 min" | "1 h 05 min"
String durationLabel(int ms) {
  final m = ms ~/ 60000;
  if (m < 1) return 'under 1 min';
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}

/// "9:41 PM" | "21:41"
String timeLabel(DateTime t, {required bool h24}) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (h24) return '${t.hour.toString().padLeft(2, '0')}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Whole calendar days from [t] to [now] (DST-safe).
int _daysAgo(DateTime t, DateTime now) => DateTime.utc(
  now.year,
  now.month,
  now.day,
).difference(DateTime.utc(t.year, t.month, t.day)).inDays;

/// Same day: hour >= 18 ? "Tonight" : "Today"; else "Sat 21 Nov"
/// (+ " 2025" if another year).
String dayLabel(DateTime t, DateTime now) {
  if (_day(t) == _day(now)) return t.hour >= 18 ? 'Tonight' : 'Today';
  final s =
      '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1].substring(0, 3)}';
  return t.year == now.year ? s : '$s ${t.year}';
}

/// "TODAY" | "THIS WEEK" (previous 6 calendar days) | "OCTOBER" (+ year).
String groupLabel(DateTime t, DateTime now) {
  final d = _daysAgo(t, now);
  if (d == 0) return 'TODAY';
  if (d > 0 && d <= 6) return 'THIS WEEK';
  final m = _months[t.month - 1].toUpperCase();
  return t.year == now.year ? m : '$m ${t.year}';
}

/// No names: "Players 1–N"; else first 3 names in seat order + " +K".
String circleLabel(List<Player> players) {
  final names = [
    for (final p in players)
      if (p.name != null) p.name!,
  ];
  if (names.isEmpty) return 'Players 1–${players.length}';
  final shown = names.take(3).join(', ');
  final rest = players.length - names.take(3).length;
  return rest > 0 ? '$shown +$rest' : shown;
}

String roundsLabel(int n) => n == 1 ? '1 round' : '$n rounds';

String resultLabel(RoundResult r) => switch (r) {
  RoundResult.truth => 'Truth',
  RoundResult.dare => 'Dare',
  RoundResult.pass => 'Passed · no penalty',
};

import 'package:equatable/equatable.dart';

class Attendance extends Equatable {
  const Attendance({
    required this.day,
    required this.checkIn,
    required this.status,
    this.checkOut,
    this.source = 'app',
  });
  final DateTime day, checkIn;
  final DateTime? checkOut;
  final String status;
  final String source;
  Duration hours(DateTime now) => (checkOut ?? now).difference(checkIn);
  @override
  List<Object?> get props => [day, checkIn, checkOut, status, source];
}

class WorkMonth extends Equatable {
  const WorkMonth(
    this.records,
    this.holidays,
    this.workDays,
    this.today, {
    this.open,
    this.joinedAt,
    this.holidayNames = const {},
    this.leaveUnits = const {},
  });
  final Attendance? open;
  final DateTime? joinedAt;
  final List<Attendance> records;
  final Set<String> holidays;
  final Map<String, String> holidayNames;
  final Map<String, double> leaveUnits;
  final List<int> workDays;
  final DateTime today;
  @override
  List<Object?> get props => [
    records,
    holidays,
    workDays,
    today,
    open,
    joinedAt,
    holidayNames,
    leaveUnits,
  ];
  bool scheduled(DateTime d) =>
      (joinedAt == null || !d.isBefore(joinedAt!)) &&
      workDays.contains(d.weekday % 7) &&
      !holidays.contains(key(d)) &&
      (leaveUnits[key(d)] ?? 0) < 1;
  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

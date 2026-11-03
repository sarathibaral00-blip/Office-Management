import 'package:equatable/equatable.dart';

class TeamAttendance extends Equatable {
  const TeamAttendance(this.name, this.code, this.status, this.source);
  final String name, code, status, source;
  @override
  List<Object?> get props => [name, code, status, source];
}

class DashboardBalance extends Equatable {
  const DashboardBalance(this.name, this.remaining, this.paid);
  final String name;
  final double remaining;
  final bool paid;
  @override
  List<Object?> get props => [name, remaining, paid];
}

class DashboardData extends Equatable {
  const DashboardData({
    required this.role,
    required this.headcount,
    required this.present,
    required this.late,
    required this.onLeave,
    required this.pending,
    required this.chart,
    required this.team,
    required this.balances,
    required this.unreadNotices,
    required this.unreadNotifications,
  });
  final String role;
  final int headcount,
      present,
      late,
      onLeave,
      pending,
      unreadNotices,
      unreadNotifications;
  final List<double> chart;
  final List<TeamAttendance> team;
  final List<DashboardBalance> balances;
  @override
  List<Object?> get props => [
    role,
    headcount,
    present,
    late,
    onLeave,
    pending,
    chart,
    team,
    balances,
    unreadNotices,
    unreadNotifications,
  ];
}

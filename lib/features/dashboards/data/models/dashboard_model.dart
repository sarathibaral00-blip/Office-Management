import '../../domain/entities/dashboards.dart';

class DashboardModel extends DashboardData {
  DashboardModel.fromJson(Map<String, dynamic> j)
    : super(
        role: j['role'] as String,
        headcount: (j['headcount'] as num).toInt(),
        present: (j['present_today'] as num).toInt(),
        late: (j['late_today'] as num).toInt(),
        onLeave: (j['on_leave'] as num).toInt(),
        pending: (j['pending'] as num).toInt(),
        chart: (j['chart'] as List).map((n) => (n as num).toDouble()).toList(),
        team: (j['team'] as List).map((v) {
          final t = v as Map;
          return TeamAttendance(
            t['name'] as String,
            t['code'] as String,
            t['status'] as String,
            t['source'] as String,
          );
        }).toList(),
        balances: (j['balances'] as List).map((v) {
          final b = v as Map;
          return DashboardBalance(
            b['name'] as String,
            (b['remaining'] as num).toDouble(),
            b['paid'] as bool,
          );
        }).toList(),
        unreadNotices: (j['unread_notices'] as num).toInt(),
        unreadNotifications: (j['unread_notifications'] as num).toInt(),
      );
}

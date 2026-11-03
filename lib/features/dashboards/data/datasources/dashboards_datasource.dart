import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/dashboards.dart';
import '../models/dashboard_model.dart';

class DashboardsDataSource {
  DashboardsDataSource(this.client);
  final SupabaseClient client;
  Future<DashboardData> load() async => DashboardModel.fromJson(
    Map<String, dynamic>.from(await client.rpc('role_dashboard') as Map),
  );
}

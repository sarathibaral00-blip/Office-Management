import '../../../../core/error/result.dart';
import '../entities/dashboards.dart';

abstract class DashboardsRepository {
  Future<Result<DashboardData>> load();
}

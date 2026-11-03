import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/dashboards.dart';
import '../../domain/repositories/dashboards_repository.dart';
import '../datasources/dashboards_datasource.dart';

class DashboardsRepositoryImpl implements DashboardsRepository {
  DashboardsRepositoryImpl(this.source);
  final DashboardsDataSource source;
  @override
  Future<Result<DashboardData>> load() => guard(() => source.load());
}

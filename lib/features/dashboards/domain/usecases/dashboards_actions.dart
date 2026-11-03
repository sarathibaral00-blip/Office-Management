import '../../../../core/error/result.dart';
import '../entities/dashboards.dart';
import '../repositories/dashboards_repository.dart';

class DashboardsActions {
  DashboardsActions(this.repository);
  final DashboardsRepository repository;
  Future<Result<DashboardData>> load() => repository.load();
}

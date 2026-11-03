import 'package:http/http.dart' as http;
import '../../features/weather/data/datasources/weather_datasource.dart';
import '../../features/weather/data/repositories_impl/weather_repository_impl.dart';
import '../../features/weather/domain/repositories/weather_repository.dart';
import '../../features/weather/domain/usecases/get_weather.dart';
import '../../features/weather/presentation/bloc/weather_cubit.dart';
import '../../features/preferences/data/datasources/preferences_datasource.dart';
import '../../features/preferences/data/repositories_impl/preferences_repository_impl.dart';
import '../../features/preferences/domain/repositories/preferences_repository.dart';
import '../../features/preferences/domain/usecases/preferences_actions.dart';
import '../../features/preferences/presentation/bloc/preferences_cubit.dart';
import '../../features/settings/data/datasources/settings_datasource.dart';
import '../../features/settings/data/repositories_impl/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/settings_actions.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../../features/exports/data/datasources/exports_datasource.dart';
import '../../features/exports/data/repositories_impl/exports_repository_impl.dart';
import '../../features/exports/domain/repositories/exports_repository.dart';
import '../../features/exports/domain/usecases/exports_actions.dart';
import '../../features/exports/presentation/bloc/exports_cubit.dart';
import '../../features/letters/data/datasources/letters_datasource.dart';
import '../../features/letters/data/repositories_impl/letters_repository_impl.dart';
import '../../features/letters/domain/repositories/letters_repository.dart';
import '../../features/letters/domain/usecases/letters_actions.dart';
import '../../features/letters/presentation/bloc/letters_cubit.dart';
import '../../features/documents/data/datasources/documents_datasource.dart';
import '../../features/documents/data/repositories_impl/documents_repository_impl.dart';
import '../../features/documents/domain/repositories/documents_repository.dart';
import '../../features/documents/domain/usecases/documents_actions.dart';
import '../../features/documents/presentation/bloc/documents_cubit.dart';
import '../../features/expenses/data/datasources/expenses_datasource.dart';
import '../../features/expenses/data/repositories_impl/expenses_repository_impl.dart';
import '../../features/expenses/domain/repositories/expenses_repository.dart';
import '../../features/expenses/domain/usecases/expenses_actions.dart';
import '../../features/expenses/presentation/bloc/expenses_cubit.dart';
import '../../features/financing/data/datasources/financing_datasource.dart';
import '../../features/financing/data/repositories_impl/financing_repository_impl.dart';
import '../../features/financing/domain/repositories/financing_repository.dart';
import '../../features/financing/domain/usecases/financing_actions.dart';
import '../../features/financing/presentation/bloc/financing_cubit.dart';
import '../../features/payroll/data/datasources/payroll_datasource.dart';
import '../../features/payroll/data/repositories_impl/payroll_repository_impl.dart';
import '../../features/payroll/domain/repositories/payroll_repository.dart';
import '../../features/payroll/domain/usecases/payroll_actions.dart';
import '../../features/payroll/presentation/bloc/payroll_cubit.dart';
import '../../features/profile/data/datasources/profile_datasource.dart';
import '../../features/profile/data/repositories_impl/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/profile_actions.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/attendance_reports/data/datasources/attendance_reports_datasource.dart';
import '../../features/attendance_reports/data/repositories_impl/attendance_reports_repository_impl.dart';
import '../../features/attendance_reports/domain/repositories/attendance_reports_repository.dart';
import '../../features/attendance_reports/domain/usecases/attendance_reports_actions.dart';
import '../../features/attendance_reports/presentation/bloc/attendance_reports_cubit.dart';
import '../../features/dashboards/data/datasources/dashboards_datasource.dart';
import '../../features/dashboards/data/repositories_impl/dashboards_repository_impl.dart';
import '../../features/dashboards/domain/repositories/dashboards_repository.dart';
import '../../features/dashboards/domain/usecases/dashboards_actions.dart';
import '../../features/dashboards/presentation/bloc/dashboards_cubit.dart';
import '../../features/notifications/data/datasources/notifications_datasource.dart';
import '../../features/notifications/data/repositories_impl/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/domain/usecases/notifications_actions.dart';
import '../../features/notifications/presentation/bloc/notifications_cubit.dart';
import '../../features/notices/data/datasources/notices_datasource.dart';
import '../../features/notices/data/repositories_impl/notices_repository_impl.dart';
import '../../features/notices/domain/repositories/notices_repository.dart';
import '../../features/notices/domain/usecases/notices_actions.dart';
import '../../features/notices/presentation/bloc/notices_cubit.dart';
import '../../features/corrections/data/datasources/corrections_datasource.dart';
import '../../features/corrections/data/repositories_impl/corrections_repository_impl.dart';
import '../../features/corrections/domain/repositories/corrections_repository.dart';
import '../../features/corrections/domain/usecases/corrections_actions.dart';
import '../../features/corrections/presentation/bloc/corrections_cubit.dart';
import '../../features/holidays/data/datasources/holidays_datasource.dart';
import '../../features/holidays/data/repositories_impl/holidays_repository_impl.dart';
import '../../features/holidays/domain/repositories/holidays_repository.dart';
import '../../features/holidays/domain/usecases/holidays_actions.dart';
import '../../features/holidays/presentation/bloc/holidays_cubit.dart';
import '../../features/leave/data/datasources/leave_datasource.dart';
import '../../features/leave/data/repositories_impl/leave_repository_impl.dart';
import '../../features/leave/domain/repositories/leave_repository.dart';
import '../../features/leave/domain/usecases/leave_actions.dart';
import '../../features/leave/presentation/bloc/leave_cubit.dart';
import '../../features/employees/data/datasources/employees_datasource.dart';
import '../../features/employees/data/repositories_impl/employees_repository_impl.dart';
import '../../features/employees/domain/repositories/employees_repository.dart';
import '../../features/employees/domain/usecases/employees_actions.dart';
import '../../features/employees/presentation/bloc/employees_cubit.dart';
import '../../features/attendance_support/data/datasources/support_datasource.dart';
import '../../features/attendance_support/data/repositories_impl/support_repository_impl.dart';
import '../../features/attendance_support/domain/repositories/support_repository.dart';
import '../../features/attendance_support/domain/usecases/support_actions.dart';
import '../../features/attendance_support/presentation/bloc/support_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/repositories_impl/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_actions.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/attendance/data/datasources/attendance_datasource.dart';
import '../../features/attendance/data/repositories_impl/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/domain/usecases/attendance_actions.dart';
import '../../features/attendance/presentation/bloc/attendance_cubit.dart';
import '../../features/networks/data/datasources/network_datasource.dart';
import '../../features/networks/data/repositories_impl/network_repository_impl.dart';
import '../../features/networks/domain/repositories/network_repository.dart';
import '../../features/networks/domain/usecases/network_actions.dart';
import '../../features/networks/presentation/bloc/network_cubit.dart';

final di = GetIt.instance;
void configureDependencies(SupabaseClient client) {
  di.registerSingleton<SupabaseClient>(client);
  di.registerLazySingleton(
    () => WeatherDataSource(http.Client()),
    dispose: (source) => source.client.close(),
  );
  di.registerLazySingleton<WeatherRepository>(
    () => WeatherRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => GetWeather(di()));
  di.registerFactory(() => WeatherCubit(di()));
  di.registerLazySingleton(() => AuthDataSource(di()));
  di.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(di()));
  di.registerLazySingleton(() => AuthActions(di()));
  di.registerLazySingleton(() => AuthCubit(di()));
  di.registerFactory(() => PasswordCubit(di()));
  di.registerLazySingleton(() => AttendanceDataSource(di()));
  di.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => AttendanceActions(di()));
  di.registerFactory(() => HomeCubit(di()));
  di.registerFactory(() => HistoryCubit(di()));
  di.registerLazySingleton(() => NetworkDataSource(di()));
  di.registerLazySingleton<NetworkRepository>(
    () => NetworkRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => NetworkActions(di()));
  di.registerFactory(() => NetworkCubit(di()));
  di.registerLazySingleton(() => SupportDataSource(di()));
  di.registerLazySingleton<SupportRepository>(
    () => SupportRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => SupportActions(di()));
  di.registerFactory(() => SupportCubit(di()));
  di.registerFactory(() => ManualCubit(di()));
  di.registerFactory(() => DevicesCubit(di()));
  di.registerFactory(() => ReportCubit(di()));
  di.registerFactory(() => KioskCubit(di()));
  di.registerLazySingleton(() => EmployeesDataSource(di()));
  di.registerLazySingleton<EmployeesRepository>(
    () => EmployeesRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => EmployeesActions(di()));
  di.registerFactory(() => EmployeesCubit(di()));
  di.registerFactory(() => EmployeeDetailCubit(di()));
  di.registerLazySingleton(() => LeaveDataSource(di()));
  di.registerLazySingleton<LeaveRepository>(() => LeaveRepositoryImpl(di()));
  di.registerLazySingleton(() => LeaveActions(di()));
  di.registerFactory(() => LeaveCubit(di()));
  di.registerLazySingleton(() => HolidaysDataSource(di()));
  di.registerLazySingleton<HolidaysRepository>(
    () => HolidaysRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => HolidaysActions(di()));
  di.registerFactory(() => HolidaysCubit(di()));
  di.registerLazySingleton(() => CorrectionsDataSource(di()));
  di.registerLazySingleton<CorrectionsRepository>(
    () => CorrectionsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => CorrectionsActions(di()));
  di.registerFactory(() => CorrectionsCubit(di()));
  di.registerLazySingleton(() => NoticesDataSource(di()));
  di.registerLazySingleton<NoticesRepository>(
    () => NoticesRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => NoticesActions(di()));
  di.registerFactory(() => NoticesCubit(di()));
  di.registerLazySingleton(() => NotificationsDataSource(di()));
  di.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => NotificationsActions(di()));
  di.registerFactory(() => NotificationsCubit(di()));
  di.registerLazySingleton(() => DashboardsDataSource(di()));
  di.registerLazySingleton<DashboardsRepository>(
    () => DashboardsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => DashboardsActions(di()));
  di.registerFactory(() => DashboardsCubit(di()));
  di.registerLazySingleton(() => AttendanceReportsDataSource(di()));
  di.registerLazySingleton<AttendanceReportsRepository>(
    () => AttendanceReportsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => AttendanceReportsActions(di()));
  di.registerFactory(() => AttendanceReportsCubit(di()));
  di.registerLazySingleton(() => ProfileDataSource(di()));
  di.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => ProfileActions(di()));
  di.registerFactory(() => ProfileCubit(di()));
  di.registerLazySingleton(() => PayrollDataSource(di()));
  di.registerLazySingleton<PayrollRepository>(
    () => PayrollRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => PayrollActions(di()));
  di.registerFactory(() => PayrollCubit(di()));
  di.registerLazySingleton(() => FinancingDataSource(di()));
  di.registerLazySingleton<FinancingRepository>(
    () => FinancingRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => FinancingActions(di()));
  di.registerFactory(() => FinancingCubit(di()));
  di.registerLazySingleton(() => ExpensesDataSource(di()));
  di.registerLazySingleton<ExpensesRepository>(
    () => ExpensesRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => ExpensesActions(di()));
  di.registerFactory(() => ExpensesCubit(di()));
  di.registerLazySingleton(() => DocumentsDataSource(di()));
  di.registerLazySingleton<DocumentsRepository>(
    () => DocumentsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => DocumentsActions(di()));
  di.registerFactory(() => DocumentsCubit(di()));
  di.registerLazySingleton(() => LettersDataSource(di()));
  di.registerLazySingleton<LettersRepository>(
    () => LettersRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => LettersActions(di()));
  di.registerFactory(() => LettersCubit(di()));
  di.registerLazySingleton(() => ExportsDataSource(di()));
  di.registerLazySingleton<ExportsRepository>(
    () => ExportsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => ExportsActions(di()));
  di.registerFactory(() => ExportsCubit(di()));
  di.registerLazySingleton(() => SettingsDataSource(di()));
  di.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => SettingsActions(di()));
  di.registerFactory(() => SettingsCubit(di()));
  di.registerLazySingleton(() => PreferencesDataSource());
  di.registerLazySingleton<PreferencesRepository>(
    () => PreferencesRepositoryImpl(di()),
  );
  di.registerLazySingleton(() => PreferencesActions(di()));
  di.registerLazySingleton(() => PreferencesCubit(di()));
}

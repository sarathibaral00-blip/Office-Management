import 'package:bloc/bloc.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/weather.dart';
import '../../domain/usecases/get_weather.dart';

class WeatherCubit extends Cubit<FlowState<Weather>> {
  WeatherCubit(this.getWeather) : super(const FlowState());
  final GetWeather getWeather;
  bool _loading = false;
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    emit(FlowState(status: LoadStatus.loading, data: state.data));
    final result = await getWeather();
    _loading = false;
    if (isClosed) return;
    emit(
      FlowState(
        status: result.failure == null
            ? LoadStatus.success
            : LoadStatus.failure,
        data: result.value ?? state.data,
        message: result.failure?.message,
      ),
    );
  }
}

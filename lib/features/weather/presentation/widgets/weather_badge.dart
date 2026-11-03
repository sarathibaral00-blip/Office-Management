import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/result.dart';
import '../../../../core/localization/app_text.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/weather.dart';
import '../bloc/weather_cubit.dart';

class WeatherBadge extends StatefulWidget {
  const WeatherBadge({super.key, this.onHeader = false});
  final bool onHeader;
  @override
  State<WeatherBadge> createState() => _WeatherBadgeState();
}

class _WeatherBadgeState extends State<WeatherBadge>
    with WidgetsBindingObserver {
  late final WeatherCubit cubit;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cubit = di<WeatherCubit>()..load();
    timer = Timer.periodic(const Duration(minutes: 15), (_) => cubit.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) cubit.load();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<WeatherCubit, FlowState<Weather>>(
    bloc: cubit,
    builder: (context, state) {
      final weather = state.data;
      final colors = Theme.of(context).colorScheme;
      final stale = state.status == LoadStatus.failure;
      final icon = weather == null
          ? Icons.cloud_outlined
          : switch (weather.code) {
              0 =>
                weather.isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              >= 95 => Icons.thunderstorm_rounded,
              >= 51 && <= 67 || >= 80 && <= 82 => Icons.water_drop_rounded,
              >= 71 && <= 77 || 85 || 86 => Icons.ac_unit_rounded,
              45 || 48 => Icons.foggy,
              _ => Icons.cloud_rounded,
            };
      if (widget.onHeader) {
        return Tooltip(
          message: weather == null
              ? state.message ?? 'Loading weather'
              : '${weather.city} · ${weather.condition} · ${weather.observedAt.toLocal()} · Weather data: Open-Meteo.com',
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: state.status == LoadStatus.loading ? null : cubit.load,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22.r, color: Colors.white),
                        SizedBox(width: 6.w),
                        AppText(
                          weather == null
                              ? '—°'
                              : '${weather.celsius.round()}°C',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  AppText(
                    weather == null
                        ? (state.status == LoadStatus.loading
                              ? 'Loading…'
                              : 'Tap to retry')
                        : stale
                        ? 'Last reading'
                        : '${weather.city} · Open-Meteo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.sp, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Tooltip(
        message: weather == null
            ? state.message ?? 'Loading weather'
            : '${weather.city} · ${translate(context, weather.condition)} · ${weather.observedAt.toLocal()}${stale ? ' · Last available reading' : ''} · Weather data: Open-Meteo.com',
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(color: colors.outlineVariant, width: 1.w),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: state.status == LoadStatus.loading ? null : cubit.load,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 22.r,
                          color: weather?.code == 0
                              ? const Color(0xFFE5A11B)
                              : colors.primary,
                        ),
                        SizedBox(width: 7.w),
                        AppText(
                          weather == null
                              ? '—°'
                              : '${weather.celsius.round()}°C',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  AppText(
                    weather == null
                        ? (state.status == LoadStatus.loading
                              ? 'Loading…'
                              : 'Tap to retry')
                        : weather.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (weather != null && stale)
                    AppText(
                      'Last reading',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  AppText(
                    'Open-Meteo',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

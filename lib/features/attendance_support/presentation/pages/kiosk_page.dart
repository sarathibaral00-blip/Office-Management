import 'package:hr_management/core/localization/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/fallback.dart';
import '../bloc/support_cubit.dart';

class KioskPage extends StatefulWidget {
  const KioskPage({super.key});
  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> with WidgetsBindingObserver {
  final code = TextEditingController(), pin = TextEditingController();
  final form = GlobalKey<FormState>();
  Timer? timer, idle;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    idle?.cancel();
    code.dispose();
    pin.dispose();
    super.dispose();
  }

  void clear() {
    code.clear();
    pin.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void touch() {
    idle?.cancel();
    idle = Timer(const Duration(seconds: 30), clear);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) clear();
  }

  Future<void> punch(String action) async {
    if (!form.currentState!.validate()) return;
    final employee = code.text.trim().toUpperCase();
    final secret = pin.text;
    clear();
    await context.read<KioskCubit>().punch(
      DeviceSubmission(action: action, code: employee, pin: secret),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<KioskCubit, KioskState>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final pairing = state.pairing;
      final expired =
          pairing?.expiresAt != null &&
          !pairing!.expiresAt!.isAfter(DateTime.now());
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            title: AppText(pairing?.label ?? 'Employee terminal'),
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: state.status == LoadStatus.loading
                    ? null
                    : () {
                        clear();
                        context.read<KioskCubit>().clear();
                        context.go('/login');
                      },
                child: const AppText('HR sign in'),
              ),
            ],
          ),
          body: SafeArea(
            child: CompactPageBody(
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 56.r,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 16.h),
                  AppText(
                    DateFormat('HH:mm:ss').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  AppText(
                    pairing?.kind == 'temporary'
                        ? 'Temporary employee terminal'
                        : 'Welcome to your office',
                    style: TextStyle(fontSize: 17.sp),
                  ),
                  SizedBox(height: 20.h),
                  if (pairing == null || expired)
                    const EmptyState(
                      title: 'HR approval required',
                      message:
                          'Ask HR to register or re-pair this device. Temporary approvals expire automatically.',
                    )
                  else
                    AppCard(
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              'Ready to start or finish?',
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            const AppText(
                              'Enter your Employee ID and PIN. Your details clear after each attempt.',
                            ),
                            SizedBox(height: 20.h),
                            TextFormField(
                              controller: code,
                              enabled: state.status != LoadStatus.loading,
                              onChanged: (_) => touch(),
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                label: AppText('Employee ID'),
                              ),
                              style: TextStyle(fontSize: 17.sp),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter your Employee ID'
                                  : null,
                            ),
                            SizedBox(height: 16.h),
                            TextFormField(
                              controller: pin,
                              enabled: state.status != LoadStatus.loading,
                              onChanged: (_) => touch(),
                              obscureText: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                label: AppText('PIN'),
                              ),
                              style: TextStyle(fontSize: 17.sp),
                              validator: (v) =>
                                  v == null ||
                                      !RegExp(r'^[0-9]{6,12}$').hasMatch(v)
                                  ? 'Enter your 6–12 digit PIN'
                                  : null,
                            ),
                            SizedBox(height: 20.h),
                            AppButton(
                              label: 'Check in',
                              icon: Icons.login_rounded,
                              loading: state.status == LoadStatus.loading,
                              onPressed: () => punch('check_in'),
                            ),
                            SizedBox(height: 12.h),
                            AppButton(
                              label: 'Check out',
                              icon: Icons.logout_rounded,
                              onPressed: state.status == LoadStatus.loading
                                  ? null
                                  : () => punch('check_out'),
                            ),
                            SizedBox(height: 16.h),
                            StatusBadge(
                              label: 'Office network required',
                              color: Theme.of(context).colorScheme.primary,
                              icon: Icons.wifi_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 20.h),
                  AppText(
                    'Five failed PIN attempts lock your PIN. Ask HR for a reset.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp),
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

import '../widgets/login_layout.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../bloc/auth_cubit.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.spa_rounded,
            size: 64.r,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 20.h),
          AppText(
            'Pride People',
            style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 24.h),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool showPassword = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (context.read<AuthCubit>().state.status == LoadStatus.loading) return;
    if (form.currentState!.validate()) {
      context.read<AuthCubit>().login(email.text.trim(), password.text);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      final loading = state.status == LoadStatus.loading;
      final colors = Theme.of(context).colorScheme;
      final tapHeight = 48.h / ScreenUtil().scaleHeight;
      return LoginLayout(
        form: AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: email,
                  label: 'Work email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  enabled: !loading,
                  minHeight: tapHeight,
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                    size: 20.r,
                    color: colors.onSurfaceVariant,
                  ),
                  validator: (v) =>
                      v != null && RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())
                      ? null
                      : 'Enter a valid work email',
                ),
                AppTextField(
                  controller: password,
                  label: 'Password',
                  obscure: !showPassword,
                  enabled: !loading,
                  minHeight: tapHeight,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submit(),
                  autofillHints: const [AutofillHints.password],
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    size: 20.r,
                    color: colors.onSurfaceVariant,
                  ),
                  suffixIcon: IconButton(
                    tooltip: showPassword ? 'Hide password' : 'Show password',
                    constraints: BoxConstraints(
                      minWidth: tapHeight,
                      minHeight: tapHeight,
                    ),
                    onPressed: loading
                        ? null
                        : () => setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20.r,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size(tapHeight, tapHeight),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                    ),
                    onPressed: loading
                        ? null
                        : () => context.go('/forgot-password'),
                    child: AppText(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (state.message != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 14.h),
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: colors.errorContainer.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: AppText(
                        state.message!,
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 13.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                AppButton(
                  label: 'Login',
                  height: 52.h < tapHeight ? tapHeight : 52.h,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF800020), Color(0xFF5C0A1A)],
                  ),
                  loading: loading,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, this.update = false});
  final bool update;
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final value = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AppText(widget.update ? 'New password' : 'Reset password'),
    ),
    body: PageBody(
      child: Form(
        key: form,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                widget.update
                    ? 'Choose a secure password'
                    : 'Let’s get you back in',
                style: TextStyle(fontSize: 23.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              AppText(
                widget.update
                    ? 'Use at least 12 characters.'
                    : 'We’ll email a secure link to your work address.',
              ),
              SizedBox(height: 24.h),
              AppTextField(
                controller: value,
                label: widget.update ? 'New password' : 'Work email',
                obscure: widget.update,
                validator: (v) => widget.update
                    ? (v != null && v.length >= 12
                          ? null
                          : 'Use at least 12 characters')
                    : (v != null && v.contains('@')
                          ? null
                          : 'Enter a valid email'),
              ),
              BlocBuilder<PasswordCubit, PasswordState>(
                builder: (context, state) => Column(
                  children: [
                    if (state.message != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: AppText(state.message!),
                      ),
                    AppButton(
                      label: widget.update
                          ? 'Update password'
                          : 'Send reset link',
                      loading: state.status == LoadStatus.loading,
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        await context.read<PasswordCubit>().submit(
                          widget.update ? value.text : value.text.trim(),
                          update: widget.update,
                        );
                        if (context.mounted &&
                            widget.update &&
                            context.read<PasswordCubit>().state.status ==
                                LoadStatus.success) {
                          context.read<AuthCubit>().completeRecovery();
                          context.go('/home');
                        }
                      },
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const AppText('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/profile.dart';
import '../bloc/profile_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final phone = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool initialized = false;
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().load();
  }

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ProfileCubit, FlowState<MyProfile>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
      if (!initialized && state.data != null) {
        phone.text = state.data!.phone ?? '';
        initialized = true;
      }
    },
    builder: (context, state) {
      final p = state.data;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Your profile'),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading && p == null)
              const Loader()
            else if (p == null)
              EmptyState(
                title: 'Profile unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => context.read<ProfileCubit>().load(),
              )
            else ...[
              AppCard(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(56.r),
                      child: p.photoUrl == null
                          ? CircleAvatar(
                              radius: 48.r,
                              child: Icon(Icons.person_outline, size: 48.r),
                            )
                          : Image.network(
                              p.photoUrl!,
                              width: 96.r,
                              height: 96.r,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Icon(Icons.person_outline, size: 96.r),
                            ),
                    ),
                    SizedBox(height: 16.h),
                    AppText(
                      p.name,
                      style: TextStyle(
                        fontSize: 23.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppText(
                      '${p.code} · ${p.email}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    SizedBox(height: 16.h),
                    AppButton(
                      label: 'Choose profile photo',
                      icon: Icons.photo_library_outlined,
                      loading: state.busy,
                      onPressed: () => context.read<ProfileCubit>().photo(),
                    ),
                    SizedBox(height: 12.h),
                    AppText(
                      'JPEG, PNG or WebP · up to 5 MB · private to your account',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Contact details',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    AppTextField(
                      controller: phone,
                      label: 'Phone number',
                      keyboardType: TextInputType.phone,
                      validator: (_) => null,
                    ),
                    AppButton(
                      label: 'Save phone number',
                      loading: state.busy,
                      onPressed: () =>
                          context.read<ProfileCubit>().phone(phone.text.trim()),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Change password',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    AppTextField(
                      controller: password,
                      label: 'New password (12+ characters)',
                      obscure: true,
                    ),
                    AppTextField(
                      controller: confirm,
                      label: 'Confirm new password',
                      obscure: true,
                    ),
                    AppButton(
                      label: 'Update password',
                      loading: state.busy,
                      onPressed: () {
                        if (password.text.length < 12 ||
                            password.text != confirm.text) {
                          toast(
                            context,
                            'Use at least 12 characters and matching passwords.',
                          );
                          return;
                        }
                        final value = password.text;
                        password.clear();
                        confirm.clear();
                        context.read<ProfileCubit>().password(value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

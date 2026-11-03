import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/documents.dart';
import '../bloc/documents_cubit.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String? employee;
  String kind = 'nid';
  final title = TextEditingController();
  @override
  void initState() {
    super.initState();
    context.read<DocumentsCubit>().load();
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<DocumentsCubit, FlowState<DocumentData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<DocumentsCubit>();
      final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Employee documents'),
            SizedBox(height: 8.h),
            const AppText(
              'Private files, visible only to their employee and HR.',
            ),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Documents unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: c.load,
              )
            else ...[
              AppCard(
                child: Column(
                  children: [
                    if (admin)
                      ChoiceField(
                        label: 'Employee',
                        items: data.employees,
                        value: employee,
                        required: true,
                        onChanged: (v) => employee = v,
                      ),
                    ChoiceField(
                      label: 'Document type',
                      items: const [
                        Choice('nid', 'NID'),
                        Choice('cv', 'CV'),
                        Choice('certificate', 'Certificate'),
                        Choice('contract', 'Contract'),
                      ],
                      value: kind,
                      required: true,
                      onChanged: (v) => kind = v!,
                    ),
                    AppTextField(controller: title, label: 'Document title'),
                    AppButton(
                      label: 'Choose & upload document',
                      loading: state.busy,
                      onPressed: () {
                        final owner = admin ? employee : data.self;
                        if (owner == null || title.text.trim().length < 3) {
                          toast(
                            context,
                            'Choose an employee and document title.',
                          );
                          return;
                        }
                        c.upload(owner, kind, title.text.trim());
                      },
                    ),
                    SizedBox(height: 12.h),
                    AppText(
                      'PDF / PNG / JPEG · up to 10 MB · previous uploads are kept',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              if (data.documents.isEmpty)
                const EmptyState(
                  title: 'No documents yet',
                  message: 'Upload your first employee document.',
                ),
              ...data.documents.map(
                (d) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          d.title,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText('${d.name} · ${d.kind.toUpperCase()}'),
                        AppText(
                          DateFormat('dd MMM yyyy').format(d.date.toLocal()),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        TextButton.icon(
                          onPressed: state.busy
                              ? null
                              : () => c.download(d.path, d.title),
                          icon: Icon(Icons.download_outlined, size: 18.r),
                          label: const AppText('Download private file'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

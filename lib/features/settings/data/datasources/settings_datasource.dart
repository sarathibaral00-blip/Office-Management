import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/settings.dart';
import '../models/shift_model.dart';
import 'package:image_picker/image_picker.dart';
import '../../../profile/data/models/photo_format.dart';

class SettingsDataSource {
  SettingsDataSource(this.client);
  final SupabaseClient client;

  Future<SettingsData> load(int auditOffset) async {
    final c = await client.from('company_settings').select().maybeSingle();
    final shifts = await client.from('shifts').select().order('name');
    final permissions = await client
        .from('role_permissions')
        .select()
        .order('role')
        .order('permission');
    final allowed =
        await client.rpc('has_permission', params: {'p_key': 'audit.view'})
            as bool;
    final audit = allowed
        ? Map<String, dynamic>.from(
            await client.rpc('audit_records', params: {'p_offset': auditOffset})
                as Map,
          )
        : <String, dynamic>{'rows': [], 'has_more': false};
    return SettingsData(
      c == null ? null : CompanyPolicy(Map<String, Object?>.from(c)),
      shifts.map((j) => ShiftModel.fromJson(j)).toList(),
      permissions
          .map(
            (j) => RoleCapability(
              j['role'] as String,
              j['permission'] as String,
              j['enabled'] as bool,
            ),
          )
          .toList(),
      (audit['rows'] as List)
          .map((j) => Map<String, Object?>.from(j as Map))
          .toList(),
      audit['has_more'] as bool,
    );
  }

  Future<void> company(Map<String, Object?> data) async {
    await client.rpc('save_company_settings', params: {'p_data': data});
  }

  Future<void> asset(String kind) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final format = photoFormat(bytes);
    if (format == null ||
        !['jpg', 'png'].contains(format.extension) ||
        bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('Choose a PNG or JPEG under 2 MB.');
    }
    final path =
        '${kind == 'logo' ? 'logos' : 'signatures'}/${DateTime.now().microsecondsSinceEpoch}.${format.extension}';
    await client.storage
        .from('company-assets')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: format.mime, upsert: false),
        );
    await client.rpc(
      'set_company_asset',
      params: {'p_kind': kind, 'p_path': path},
    );
  }

  Future<void> shift(String? id, Map<String, Object?> data) async {
    await client.rpc('save_shift', params: {'p_id': id, ...data});
  }

  Future<void> permission(String role, String key, bool enabled) async {
    await client.rpc(
      'set_role_permission',
      params: {'p_role': role, 'p_key': key, 'p_enabled': enabled},
    );
  }
}

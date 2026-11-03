import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employees.dart';
import '../../../../core/domain/page_result.dart';
import '../models/staff_model.dart';

class EmployeesDataSource {
  EmployeesDataSource(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> all(String table, String fields) async {
    final out = <Map<String, dynamic>>[];
    for (var start = 0; ; start += 200) {
      final rows = await client
          .from(table)
          .select(fields)
          .order('id')
          .range(start, start + 199);
      out.addAll(rows);
      if (rows.length < 200) return out;
    }
  }

  Future<Directory> list(
    String search,
    String? department,
    String? branch,
    bool? active,
    int offset,
  ) async {
    var query = client.from('profiles').select();
    final safe = search.trim().replaceAll(RegExp(r'[(),%]'), '');
    if (safe.isNotEmpty) {
      query = query.or(
        'full_name.ilike.%$safe%,employee_code.ilike.%$safe%,email.ilike.%$safe%',
      );
    }
    if (department != null) query = query.eq('department_id', department);
    if (branch != null) query = query.eq('branch_id', branch);
    if (active != null) query = query.eq('is_active', active);
    final rows = await query
        .order('full_name')
        .order('id')
        .range(offset, offset + 25);
    final deps = await all('departments', 'id,name');
    final branches = await all('branches', 'id,name');
    final managers = await all('profiles', 'id,full_name,role,is_active');
    final shifts = await all('shifts', 'id,name');
    List<Choice> choices(List<Map<String, dynamic>> rows) => rows
        .map((j) => Choice(j['id'] as String, j['name'] as String))
        .toList();
    return Directory(
      PageResult(
        rows.take(25).map(StaffModel.fromJson).toList(),
        rows.length > 25,
      ),
      choices(deps),
      choices(branches),
      managers
          .where(
            (j) =>
                j['is_active'] == true &&
                ['manager', 'hr', 'super_admin'].contains(j['role']),
          )
          .map((j) => Choice(j['id'] as String, j['full_name'] as String))
          .toList(),
      choices(shifts),
    );
  }

  Future<Choice> createDepartment(String name) async {
    final value = name.trim();
    if (value.length < 2) {
      throw const FormatException(
        'Enter at least 2 characters for the department name.',
      );
    }
    final row = await client
        .from('departments')
        .insert({'name': value})
        .select('id,name')
        .single();
    return Choice(row['id'] as String, row['name'] as String);
  }

  Future<Staff> detail(String id) async => StaffModel.fromJson(
    await client.from('profiles').select().eq('id', id).single(),
  );
  Future<void> create(Map<String, Object?> data) async {
    await client.functions.invoke('create-employee', body: data);
  }

  Future<void> update(String id, Map<String, Object?> data) async {
    await client.rpc(
      'update_employee',
      params: {'p_employee': id, 'p_data': data},
    );
  }

  Future<void> pin(String id, String pin) async {
    await client.functions.invoke(
      'attendance-admin',
      body: {
        'action': 'set_pin',
        'data': {'employee_id': id, 'pin': pin},
      },
    );
  }
}

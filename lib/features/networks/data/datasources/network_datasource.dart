import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/network.dart';
import '../models/network_model.dart';

class NetworkDataSource {
  NetworkDataSource(this.client);
  final SupabaseClient client;
  Future<Branch> createBranch(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw const FormatException(
        'Enter a branch name between 1 and 100 characters.',
      );
    }
    try {
      // Existing branches RLS permits only HR/super_admin to create branches.
      // Use the existing database timezone default; do not create networks or
      // reassign employee branches until HR explicitly saves those changes.
      final row = await client
          .from('branches')
          .insert({'name': trimmed})
          .select('id,name')
          .single();
      return Branch(row['id'] as String, row['name'] as String);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const FormatException(
          'A branch with this name already exists. Close this form and retry adding your IP to reload branches.',
        );
      }
      if (e.code == '42501') {
        throw const FormatException(
          'Only active HR or super admin users can create a branch.',
        );
      }
      rethrow;
    }
  }

  Future<NetworkList> list() async {
    final n = await client
        .from('allowed_networks')
        .select()
        .order('created_at');
    final b = await client.from('branches').select('id,name').order('name');
    return NetworkList(
      n.map(NetworkModel.fromJson).toList(),
      b.map((j) => Branch(j['id'] as String, j['name'] as String)).toList(),
    );
  }

  Future<void> save({
    String? id,
    required String label,
    required String network,
    required String branchId,
    required bool active,
  }) async {
    final j = {
      'label': label,
      'network': network,
      'branch_id': branchId,
      'is_active': active,
    };
    if (id == null) {
      await client.from('allowed_networks').insert(j);
    } else {
      await client.from('allowed_networks').update(j).eq('id', id);
    }
  }

  Future<void> delete(String id) async {
    await client.from('allowed_networks').delete().eq('id', id);
  }

  Future<String> currentIp() async {
    if (kDebugMode) {
      debugPrint(
        '[Office IP] Calling check-in action=current_ip; '
        'sessionPresent=${client.auth.currentSession != null}',
      );
    }
    try {
      if (client.auth.currentSession == null) {
        throw const FormatException(
          'Please sign in again to detect your office IP.',
        );
      }
      final r = await client.functions.invoke(
        'check-in',
        body: {'action': 'current_ip'},
      );
      final data = r.data;
      final ip = data is Map ? data['ip'] : null;
      if (ip is! String || ip.trim().isEmpty) {
        throw const FormatException(
          'The check-in function returned no IP address. Check its deployment and logs.',
        );
      }
      if (kDebugMode) {
        debugPrint('[Office IP] Success: HTTP ${r.status}; IP received.');
      }
      return ip.trim();
    } on FunctionException catch (e) {
      final message = _currentIpError(e);
      if (kDebugMode) {
        // Never dump exceptions, headers, sessions or response bodies: those
        // may contain credentials. Log status and a classified reason only.
        debugPrint('[Office IP] Failed: HTTP ${e.status}; $message');
      }
      throw FormatException(message);
    } on FormatException catch (e) {
      if (kDebugMode) debugPrint('[Office IP] ${e.message}');
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Office IP] Transport/client failure: ${e.runtimeType}. '
          'Check internet, browser CORS and check-in deployment.',
        );
      }
      rethrow;
    }
  }
}

String _currentIpError(FunctionException error) {
  if (error.status == 0) {
    return 'Could not reach the check-in service. Check internet, browser CORS and the Edge Function deployment.';
  }
  final details = error.details;
  final text =
      (details is Map
              ? '${details['error'] ?? ''} ${details['message'] ?? ''}'
              : '')
          .toLowerCase();
  if (error.status == 404) {
    return 'The check-in Edge Function was not found (HTTP 404). Deploy it to this project.';
  }
  if (error.status == 401) {
    return text.contains('invalid jwt')
        ? 'The check-in gateway rejected the session (HTTP 401: Invalid JWT). Check the deployed verify_jwt configuration, then sign in again.'
        : 'Your session was rejected (HTTP 401). Sign out and sign in again.';
  }
  if (error.status == 403) {
    return 'Access denied (HTTP 403). An active HR or super admin profile is required.';
  }
  if (text.contains('unable to verify office network')) {
    return 'The server could not detect your public IP. Check forwarded-IP headers in the check-in deployment.';
  }
  if (error.status >= 500) {
    return 'The check-in service failed (HTTP ${error.status}). Check its Supabase logs and runtime configuration.';
  }
  return 'IP lookup failed (HTTP ${error.status}). Check the check-in Edge Function logs for action current_ip.';
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthDataSource {
  AuthDataSource(this.client);
  final SupabaseClient client;
  Stream<AuthSessionEvent> get changes => client.auth.onAuthStateChange.map(
    (event) => event.event == AuthChangeEvent.passwordRecovery
        ? AuthSessionEvent.passwordRecovery
        : AuthSessionEvent.changed,
  );
  Future<EmployeeModel?> restore() async {
    final u = client.auth.currentUser;
    if (u == null) return null;
    final p = EmployeeModel.fromJson(
      await client.from('profiles').select().eq('id', u.id).single(),
    );
    if (!p.active) {
      await client.auth.signOut();
      throw const AuthException('Your account is inactive. Contact HR.');
    }
    return p;
  }

  Future<EmployeeModel?> login(String e, String p) async {
    await client.auth.signInWithPassword(email: e, password: p);
    return restore();
  }

  Future<void> reset(String e) => client.auth.resetPasswordForEmail(
    e,
    redirectTo: const String.fromEnvironment(
      'PASSWORD_RESET_REDIRECT',
      defaultValue: 'hrmanagement://reset-password',
    ),
  );
  Future<void> logout() => client.auth.signOut();
  Future<void> password(String p) async {
    await client.auth.updateUser(UserAttributes(password: p));
  }
}

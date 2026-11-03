import '../../domain/entities/profile.dart';

class ProfileModel extends MyProfile {
  ProfileModel.fromJson(Map<String, dynamic> j, String? url)
    : super(
        j['id'] as String,
        j['full_name'] as String,
        j['employee_code'] as String? ?? '',
        j['email'] as String? ?? '',
        j['phone'] as String?,
        url,
      );
}

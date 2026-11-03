import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/profile.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile_model.dart';
import '../models/photo_format.dart';

class ProfileDataSource {
  ProfileDataSource(this.client);
  final SupabaseClient client;

  Future<MyProfile> load() async {
    final j = await client
        .from('profiles')
        .select('id,full_name,employee_code,email,phone,photo_path')
        .eq('id', client.auth.currentUser!.id)
        .single();
    final path = j['photo_path'] as String?;
    final url = path == null
        ? null
        : await client.storage
              .from('profile-photos')
              .createSignedUrl(path, 300);
    return ProfileModel.fromJson(j, url);
  }

  Future<void> phone(String phone) async {
    await client.rpc(
      'save_my_profile',
      params: {'p_phone': phone, 'p_photo_path': null},
    );
  }

  Future<void> photo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final format = photoFormat(bytes);
    if (format == null) {
      throw const FormatException(
        'Choose a JPEG, PNG or WebP image under 5 MB.',
      );
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw const FormatException('Sign in again before uploading.');
    }
    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.${format.extension}';
    await client.storage
        .from('profile-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: format.mime, upsert: false),
        );
    await client.rpc(
      'save_my_profile',
      params: {
        'p_phone': null,
        'p_photo_path': path,
        'p_replace_photo': true,
        'p_update_phone': false,
      },
    );
  }

  Future<void> password(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }
}

import 'file_validation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'export_service.dart';

class PrivateFileStore {
  PrivateFileStore(this.client);
  final SupabaseClient client;
  Future<String?> upload(String bucket, String owner) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const FormatException('Unable to read the selected file.');
    }
    final format = privateFileFormat(bytes);
    if (format == null) {
      throw const FormatException('Choose a PDF, PNG or JPEG under 10 MB.');
    }
    final path =
        '$owner/${DateTime.now().microsecondsSinceEpoch}.${format.extension}';
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: format.mime, upsert: false),
        );
    return path;
  }

  Future<void> download(String bucket, String path, String label) async {
    final bytes = await client.storage.from(bucket).download(path);
    final ext = path.split('.').last;
    await ExportService().deliver(
      bytes,
      '${label.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.$ext',
      ext,
    );
  }
}

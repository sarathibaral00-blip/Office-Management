import 'dart:io';
import 'dart:typed_data';

Future<void> writeSelectedFile(String path, Uint8List bytes) async {
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}

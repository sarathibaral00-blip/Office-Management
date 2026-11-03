import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'file_write_stub.dart' if (dart.library.io) 'file_write_io.dart';
import 'report_data.dart';
import 'tabular_codec.dart';
import 'pdf_renderer.dart';

class ExportService {
  Future<void> report(
    ReportData data,
    String filename,
    String format, {
    bool share = false,
  }) async {
    final bytes = switch (format) {
      'csv' => csvBytes(data),
      'xlsx' => xlsxBytes(data),
      _ => await pdfBytes(data),
    };
    await deliver(bytes, '$filename.$format', format, share: share);
  }

  Future<void> deliver(
    Uint8List bytes,
    String name,
    String extension, {
    bool share = false,
  }) async {
    final mime = switch (extension) {
      'csv' => 'text/csv',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
    if (share) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mime, name: name)],
          fileNameOverrides: [name],
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
    } else {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $name',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );
      if (path != null) await writeSelectedFile(path, bytes);
    }
  }
}

import 'dart:typed_data';

class ReportData {
  const ReportData({
    required this.title,
    this.subtitle = '',
    this.headers = const [],
    this.rows = const [],
    this.paragraphs = const [],
    this.logo,
    this.signature,
  });
  final String title, subtitle;
  final List<String> headers, paragraphs;
  final List<List<Object?>> rows;
  final Uint8List? logo, signature;
}

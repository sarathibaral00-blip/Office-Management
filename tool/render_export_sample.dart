import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:hr_management/core/export/pdf_renderer.dart';
import 'package:hr_management/core/export/report_data.dart';
import 'package:hr_management/core/export/tabular_codec.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const directory = '/tmp/hr-export-verification';
  await Directory(directory).create(recursive: true);
  final data = ReportData(
    title: 'Payslip verification',
    subtitle: 'Pride People · Test fixture',
    paragraphs: const [
      'Employee: Sample Employee (EMP-TEST)',
      'These are synthetic test amounts.',
    ],
    headers: const ['Component', 'Amount'],
    rows: List.generate(90, (i) => ['Component ${i + 1}', (i + 1) * 12.25]),
  );
  await File('$directory/sample.pdf').writeAsBytes(await pdfBytes(data));
  await File('$directory/sample.xlsx').writeAsBytes(xlsxBytes(data));
  await File('$directory/sample.csv').writeAsBytes(csvBytes(data));
  stdout.writeln('Rendered PDF, XLSX and CSV fixtures in $directory');
  exit(0);
}

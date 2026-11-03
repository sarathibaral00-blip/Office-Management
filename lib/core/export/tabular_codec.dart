import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'report_data.dart';

String safeCsvCell(Object? value) {
  final text = value?.toString() ?? '';
  final probe = text.trimLeft();
  return RegExp(r'^[=+@\-\t\r\n]').hasMatch(probe) ||
          RegExp(r'^[\t\r\n]').hasMatch(text)
      ? "'$text"
      : text;
}

Uint8List csvBytes(ReportData data) => Uint8List.fromList([
  239,
  187,
  191,
  ...utf8.encode(
    [data.headers, ...data.rows]
        .map(
          (row) => row
              .map((c) => '"${safeCsvCell(c).replaceAll('"', '""')}"')
              .join(','),
        )
        .join('\r\n'),
  ),
]);
String xmlText(Object? value) => (value?.toString() ?? '')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
String columnName(int index) {
  var n = index + 1;
  var out = '';
  while (n > 0) {
    n--;
    out = String.fromCharCode(65 + n % 26) + out;
    n = n ~/ 26;
  }
  return out;
}

Uint8List xlsxBytes(ReportData data) {
  final archive = Archive();
  void add(String name, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>''',
  );
  add(
    '_rels/.rels',
    '''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''',
  );
  add(
    'xl/workbook.xml',
    '''<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets></workbook>''',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>''',
  );
  add(
    'xl/styles.xml',
    '''<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>''',
  );
  final rows = [data.headers, ...data.rows];
  final sheet = StringBuffer(
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      final ref = '${columnName(c)}${r + 1}';
      if (v is num && v.isFinite) {
        sheet.write('<c r="$ref"><v>$v</v></c>');
      } else {
        sheet.write(
          '<c r="$ref" t="inlineStr"${r == 0 ? ' s="1"' : ''}><is><t xml:space="preserve">${xmlText(v)}</t></is></c>',
        );
      }
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');
  add('xl/worksheets/sheet1.xml', sheet.toString());
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:archive/archive.dart';
import 'report_data.dart';

// Print geometry is fixed A4 image geometry, independent of screen/device size.
Future<Uint8List> pdfBytes(ReportData data) async {
  const width = 1240, height = 1754, margin = 64.0;
  final images = <Uint8List>[];
  ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas canvas = ui.Canvas(recorder);
  double y = margin;
  bool tableStarted = false;
  void begin() {
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1240, 1754),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  }

  Future<void> finish() async {
    final footer = TextPainter(
      text: TextSpan(
        text: '${data.title} • ${images.length + 1}',
        style: const TextStyle(color: ui.Color(0xFF666666), fontSize: 16),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 1112);
    footer.paint(canvas, const ui.Offset(margin, 1700));
    final image = await recorder.endRecording().toImage(width, height);
    final rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    final rgb = Uint8List(width * height * 3);
    for (var src = 0, dst = 0; src < rgba.length; src += 4) {
      rgb[dst++] = rgba[src];
      rgb[dst++] = rgba[src + 1];
      rgb[dst++] = rgba[src + 2];
    }
    images.add(Uint8List.fromList(ZLibEncoder().encode(rgb)));
    image.dispose();
  }

  double cellWidth(int index) => data.headers.length == 2
      ? (width - margin * 2) * (index == 0 ? 0.7 : 0.3)
      : (width - margin * 2) / data.headers.length;
  List<TextPainter> cells(List<Object?> values, {bool header = false}) =>
      List.generate(
        data.headers.length,
        (i) => TextPainter(
          text: TextSpan(
            text: i < values.length ? values[i]?.toString() ?? '' : '',
            style: TextStyle(
              color: header
                  ? const ui.Color(0xFFFFFFFF)
                  : const ui.Color(0xFF231C1F),
              fontSize: data.headers.length > 5 ? 14 : 20,
              fontWeight: header ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: !header && i < values.length && values[i] is num
              ? TextAlign.right
              : TextAlign.left,
        )..layout(maxWidth: cellWidth(i) - 20),
      );
  void paintCells(List<TextPainter> painters, {bool header = false}) {
    final h =
        painters.fold<double>(0, (n, p) => p.height > n ? p.height : n) + 20;
    canvas.drawRect(
      ui.Rect.fromLTWH(margin, y, width - margin * 2, h),
      ui.Paint()
        ..color = header
            ? const ui.Color(0xFF800020)
            : const ui.Color(0xFFF9F5F6),
    );
    var x = margin;
    for (var i = 0; i < painters.length; i++) {
      painters[i].paint(canvas, ui.Offset(x + 10, y + 10));
      x += cellWidth(i);
    }
    canvas.drawLine(
      ui.Offset(margin, y + h),
      ui.Offset(width - margin, y + h),
      ui.Paint()
        ..color = const ui.Color(0xFFE4D9DD)
        ..strokeWidth = 1,
    );
    y += h;
  }

  Future<void> next() async {
    await finish();
    recorder = ui.PictureRecorder();
    canvas = ui.Canvas(recorder);
    y = margin;
    begin();
    final heading = TextPainter(
      text: TextSpan(
        text: data.title,
        style: const TextStyle(
          color: ui.Color(0xFF800020),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width - margin * 2);
    heading.paint(canvas, ui.Offset(margin, y));
    y += heading.height + 20;
    if (tableStarted) {
      paintCells(cells(data.headers, header: true), header: true);
    }
  }

  Future<void> text(String value, {double size = 22, bool bold = false}) async {
    var remaining = value;
    do {
      var end = remaining.length.clamp(0, 1000);
      if (end < remaining.length) {
        final space = remaining.lastIndexOf(' ', end);
        if (space > 0) {
          end = space;
        } else if (end > 0 &&
            remaining.codeUnitAt(end - 1) >= 0xD800 &&
            remaining.codeUnitAt(end - 1) <= 0xDBFF) {
          end--;
        }
      }
      final part = remaining.substring(0, end);
      remaining = remaining.substring(end);
      final painter = TextPainter(
        text: TextSpan(
          text: part,
          style: TextStyle(
            color: bold
                ? const ui.Color(0xFF800020)
                : const ui.Color(0xFF231C1F),
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - margin * 2);
      if (y + painter.height > 1650) await next();
      painter.paint(canvas, ui.Offset(margin, y));
      y += painter.height + 14;
    } while (remaining.isNotEmpty);
  }

  Future<void> picture(
    Uint8List? bytes,
    double maxWidth,
    double maxHeight,
  ) async {
    if (bytes == null) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    final scale = (maxWidth / image.width)
        .clamp(0, maxHeight / image.height)
        .toDouble();
    final h = image.height * scale;
    if (y + h > 1650) await next();
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(margin, y, image.width * scale, h),
      ui.Paint(),
    );
    y += h + 16;
    image.dispose();
    codec.dispose();
  }

  begin();
  await picture(data.logo, 240, 100);
  await text(data.title, size: 36, bold: true);
  if (data.subtitle.isNotEmpty) await text(data.subtitle, size: 19);
  for (final p in data.paragraphs) {
    await text(p);
  }
  if (data.headers.isNotEmpty) {
    tableStarted = true;
    final header = cells(data.headers, header: true);
    final headerHeight =
        header.fold<double>(0, (n, p) => p.height > n ? p.height : n) + 20;
    if (y + headerHeight > 1650) {
      await next();
    } else {
      paintCells(header, header: true);
    }
    for (final row in data.rows) {
      final painters = cells(row);
      final h =
          painters.fold<double>(0, (n, p) => p.height > n ? p.height : n) + 20;
      if (h > 1400) {
        throw const FormatException(
          'A report row is too long for PDF. Export this data to Excel or CSV.',
        );
      }
      if (y + h > 1650) await next();
      paintCells(painters);
    }
    tableStarted = false;
  }
  if (data.signature != null) {
    await text('Authorized signature', size: 18);
    await picture(data.signature, 300, 120);
  }
  await finish();
  final out = BytesBuilder();
  void raw(String s) => out.add(ascii.encode(s));
  raw('%PDF-1.4\n');
  out.add([37, 226, 227, 207, 211, 10]);
  final offsets = <int>[0];
  final count = 2 + images.length * 3;
  void object(int id, List<int> body) {
    offsets.add(out.length);
    raw('$id 0 obj\n');
    out.add(body);
    raw('\nendobj\n');
  }

  object(1, ascii.encode('<< /Type /Catalog /Pages 2 0 R >>'));
  object(
    2,
    ascii.encode(
      '<< /Type /Pages /Count ${images.length} /Kids [${List.generate(images.length, (i) => '${4 + i * 3} 0 R').join(' ')}] >>',
    ),
  );
  for (var i = 0; i < images.length; i++) {
    final base = 3 + i * 3;
    final img = images[i];
    final bytes = BytesBuilder()
      ..add(
        ascii.encode(
          '<< /Type /XObject /Subtype /Image /Width $width /Height $height /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${img.length} >>\nstream\n',
        ),
      )
      ..add(img)
      ..add(ascii.encode('\nendstream'));
    object(base, bytes.takeBytes());
    object(
      base + 1,
      ascii.encode(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595.28 841.89] /Resources << /XObject << /Im0 $base 0 R >> >> /Contents ${base + 2} 0 R >>',
      ),
    );
    const commands = 'q 595.28 0 0 841.89 0 0 cm /Im0 Do Q';
    object(
      base + 2,
      ascii.encode(
        '<< /Length ${commands.length} >>\nstream\n$commands\nendstream',
      ),
    );
  }
  final xref = out.length;
  raw('xref\n0 ${count + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    raw('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  raw(
    'trailer\n<< /Size ${count + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return out.takeBytes();
}

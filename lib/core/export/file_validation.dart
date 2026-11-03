import 'dart:typed_data';

({String mime, String extension})? privateFileFormat(Uint8List bytes) {
  if (bytes.length > 10 * 1024 * 1024 || bytes.length < 5) return null;
  if (String.fromCharCodes(bytes.take(5)) == '%PDF-') {
    return (mime: 'application/pdf', extension: 'pdf');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return (mime: 'image/jpeg', extension: 'jpg');
  }
  if (bytes.length >= 8 &&
      [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].indexed.every((e) => bytes[e.$1] == e.$2)) {
    return (mime: 'image/png', extension: 'png');
  }
  return null;
}

import 'dart:typed_data';

({String mime, String extension})? photoFormat(Uint8List bytes) {
  if (bytes.length > 5 * 1024 * 1024 || bytes.length < 12) return null;
  if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
    return (mime: 'image/jpeg', extension: 'jpg');
  }
  if ([
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
  if (bytes[0] == 82 &&
      bytes[1] == 73 &&
      bytes[2] == 70 &&
      bytes[3] == 70 &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return (mime: 'image/webp', extension: 'webp');
  }
  return null;
}

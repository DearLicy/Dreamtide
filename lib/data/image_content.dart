import 'dart:convert';
import 'dart:typed_data';

/// Detect actual file bytes rather than trusting a user-controlled extension.
class ImageContent {
  const ImageContent(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
  String get dataUrl => 'data:$mimeType;base64,${base64Encode(bytes)}';
  String get extension => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => 'jpg',
  };

  static ImageContent parse(
    Uint8List bytes, {
    int maxBytes = 10 * 1024 * 1024,
  }) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('图片为空或超过 10 MB，请选择较小的图片。');
    }
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((v) => v);
    final type = starts([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10])
        ? 'image/png'
        : starts([0xff, 0xd8, 0xff])
        ? 'image/jpeg'
        : starts([0x47, 0x49, 0x46, 0x38])
        ? 'image/gif'
        : bytes.length >= 12 &&
              ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
              ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP'
        ? 'image/webp'
        : null;
    if (type == null) {
      throw const FormatException('请选择 JPEG、PNG、GIF 或 WebP 图片。');
    }
    return ImageContent(bytes, type);
  }
}

/// A local editor draft. Nothing is persisted/uploaded until Save is pressed.
class AvatarChange {
  const AvatarChange.remove() : image = null;
  const AvatarChange.replace(this.image);
  final ImageContent? image;
}

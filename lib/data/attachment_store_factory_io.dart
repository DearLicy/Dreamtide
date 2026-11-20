import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_store_base.dart';

AttachmentStore createAttachmentStore() => _IoAttachmentStore();

class _IoAttachmentStore implements AttachmentStore {
  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'chat_attachments'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final directory = await _directory();
    final extension = switch (mimeType.toLowerCase()) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      'image/heic' || 'image/heif' => '.heic',
      _ => '.jpg',
    };
    final file = File(p.join(directory.path, '$id$extension'));
    await file.writeAsBytes(bytes, flush: true);
    return p.basename(file.path);
  }

  @override
  Future<Uint8List?> readImage(String reference) async {
    final safeName = p.basename(reference);
    if (safeName.isEmpty || safeName != reference) return null;
    final file = File(p.join((await _directory()).path, safeName));
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String reference) async {
    final safeName = p.basename(reference);
    if (safeName.isEmpty ||
        safeName != reference ||
        safeName == '.' ||
        safeName == '..') {
      return;
    }
    final file = File(p.join((await _directory()).path, safeName));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clear() async {
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

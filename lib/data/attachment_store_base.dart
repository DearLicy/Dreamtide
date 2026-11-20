import 'dart:typed_data';

/// Stores large chat attachments outside the main application JSON/database.
/// The persisted message contains only the opaque [reference] returned here.
abstract class AttachmentStore {
  Future<String> saveImage({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<Uint8List?> readImage(String reference);

  Future<void> delete(String reference);

  Future<void> clear();
}

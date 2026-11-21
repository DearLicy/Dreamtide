import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/image_content.dart';
import 'dt_avatar.dart';
import 'dt_controls.dart';
import 'dt_motion.dart';
import 'dt_sheet.dart';

class DtAvatarEditor extends StatefulWidget {
  const DtAvatarEditor({
    super.key,
    required this.name,
    required this.color,
    required this.reference,
    required this.change,
    required this.onChanged,
  });
  final String name;
  final int color;
  final String? reference;
  final AvatarChange? change;
  final ValueChanged<AvatarChange> onChanged;
  @override
  State<DtAvatarEditor> createState() => _DtAvatarEditorState();
}

class _DtAvatarEditorState extends State<DtAvatarEditor> {
  bool _loading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (file == null) return;
      final selected = ImageContent.parse(await file.readAsBytes());
      // A small square PNG is portable across Android/iOS/Web. Cropping happens
      // only locally and keeps original aspect ratio before a centered crop.
      final codec = await ui.instantiateImageCodec(
        selected.bytes,
        targetWidth: 512,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final side = image.width < image.height ? image.width : image.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          (image.width - side) / 2,
          (image.height - side) / 2,
          side.toDouble(),
          side.toDouble(),
        ),
        const Rect.fromLTWH(0, 0, 512, 512),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final square = await picture.toImage(512, 512);
      picture.dispose();
      image.dispose();
      final encoded = await square.toByteData(format: ui.ImageByteFormat.png);
      square.dispose();
      if (encoded == null) throw const FormatException('图片处理失败，请重新选择。');
      if (mounted) {
        widget.onChanged(
          AvatarChange.replace(
            ImageContent(encoded.buffer.asUint8List(), 'image/png'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : '无法读取图片，请检查相册或相机权限后重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _actions() {
    final page = context;
    showDtSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.photo_library_outlined,
                title: '从相册选择',
                onTap: () {
                  Navigator.pop(context);
                  if (page.mounted) _pick(ImageSource.gallery);
                },
              ),
              DtSettingRow(
                icon: Icons.camera_alt_outlined,
                title: '拍照',
                onTap: () {
                  Navigator.pop(context);
                  if (page.mounted) _pick(ImageSource.camera);
                },
              ),
              if ((widget.change == null && widget.reference != null) ||
                  widget.change?.image != null)
                DtSettingRow(
                  icon: Icons.person_outline,
                  title: '移除头像',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onChanged(const AvatarChange.remove());
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DtPressable(
        onTap: _loading ? null : _actions,
        semanticLabel: '更换头像',
        child: Stack(
          children: [
            if (widget.change?.image case final image?)
              ClipOval(
                child: Image.memory(
                  image.bytes,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              )
            else
              DtAvatar(
                name: widget.name,
                color: widget.color,
                size: 88,
                reference: widget.change == null ? widget.reference : null,
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    _loading
                        ? Icons.hourglass_top_rounded
                        : Icons.camera_alt_outlined,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _loading ? '正在处理图片…' : '点击更换头像 · 保存后生效',
        style: const TextStyle(fontSize: 12),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
    ],
  );
}

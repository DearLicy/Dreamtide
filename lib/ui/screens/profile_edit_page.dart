import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _signature;
  late int _color;

  @override
  void initState() {
    super.initState();
    final owner = ref.read(appControllerProvider).data.owner;
    _name = TextEditingController(text: owner.displayName);
    _signature = TextEditingController(text: owner.signature);
    _color = owner.avatarColor;
  }

  @override
  void dispose() {
    _name.dispose();
    _signature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(appControllerProvider).data.owner;
    return DtDetailPage(
      title: '个人资料',
      subtitle: '本地身份，不会上传到 Dreamtide 服务器',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              children: [
                DtAvatar(
                  name: _name.text,
                  color: _color,
                  size: 88,
                  showStatus: true,
                ),
                const SizedBox(height: 16),
                _AvatarColors(
                  selected: _color,
                  onSelect: (color) => setState(() => _color = color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    hintText: '你在 Dreamtide 的显示名',
                  ),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _signature,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '个性签名',
                    hintText: '写一句留给梦境的话',
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '在线状态',
                    helperText: '状态自定义将在 V2.1 开放',
                  ),
                  child: Text(owner.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: '保存资料',
            onPressed: () {
              ref
                  .read(appControllerProvider.notifier)
                  .updateOwner(
                    owner.copyWith(
                      displayName: _name.text.trim().isEmpty
                          ? owner.displayName
                          : _name.text.trim(),
                      signature: _signature.text.trim(),
                      avatarColor: _color,
                    ),
                  );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _AvatarColors extends StatelessWidget {
  const _AvatarColors({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const colors = [
    0xFF5478F6,
    0xFF8E72EA,
    0xFF32A99A,
    0xFFE07168,
    0xFFE590AA,
    0xFF6C7C92,
    0xFFC58B3E,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: [
        for (final color in colors)
          InkWell(
            onTap: () => onSelect(color),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == color
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected == color
                    ? [
                        BoxShadow(
                          color: Color(color).withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: selected == color
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

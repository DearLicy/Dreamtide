import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';

class PersonaEditorPage extends ConsumerStatefulWidget {
  const PersonaEditorPage({super.key, required this.personaId});

  final String personaId;

  @override
  ConsumerState<PersonaEditorPage> createState() => _PersonaEditorPageState();
}

class _PersonaEditorPageState extends ConsumerState<PersonaEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _pronouns;
  late final TextEditingController _appearance;
  late final TextEditingController _personality;
  late final TextEditingController _background;
  late final TextEditingController _preferences;
  late int _color;
  String? _id;

  @override
  void initState() {
    super.initState();
    final data = ref.read(appControllerProvider).data;
    final existing = data.personas
        .where((e) => e.id == widget.personaId)
        .firstOrNull;
    _id = existing?.id;
    _name = TextEditingController(text: existing?.name ?? '');
    _age = TextEditingController(text: existing?.age ?? '成年');
    _pronouns = TextEditingController(text: existing?.pronouns ?? '她');
    _appearance = TextEditingController(text: existing?.appearance ?? '');
    _personality = TextEditingController(text: existing?.personality ?? '');
    _background = TextEditingController(text: existing?.background ?? '');
    _preferences = TextEditingController(text: existing?.preferences ?? '');
    _color = existing?.avatarColor ?? 0xFF8E72EA;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _age,
      _pronouns,
      _appearance,
      _personality,
      _background,
      _preferences,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DtDetailPage(
      title: _id == null ? '创建梦设' : '编辑梦设',
      subtitle: '梦设只属于对应的关系，不影响其他故事',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '姓名'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _age,
                        decoration: const InputDecoration(
                          labelText: '年龄（必须成年）',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _pronouns,
                        decoration: const InputDecoration(labelText: '称呼'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _appearance,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '外貌'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _personality,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '性格'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _background,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '背景与世界观身份'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _preferences,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '喜好与互动边界'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: '保存梦设',
            onPressed: () {
              final persona = UserPersona(
                id: _id ?? 'persona_${const Uuid().v4()}',
                name: _name.text.trim().isEmpty ? '未命名梦设' : _name.text.trim(),
                age: _age.text.trim().isEmpty ? '成年' : _age.text.trim(),
                pronouns: _pronouns.text.trim().isEmpty
                    ? '她'
                    : _pronouns.text.trim(),
                appearance: _appearance.text.trim(),
                personality: _personality.text.trim(),
                background: _background.text.trim(),
                preferences: _preferences.text.trim(),
                avatarColor: _color,
              );
              ref.read(appControllerProvider.notifier).upsertPersona(persona);
              if (_id == null) {
                ref
                    .read(appControllerProvider.notifier)
                    .selectPersona(persona.id);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

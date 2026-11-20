import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';

class ScenePage extends ConsumerStatefulWidget {
  const ScenePage({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends ConsumerState<ScenePage> {
  late final TextEditingController _location;
  late final TextEditingController _time;
  late final TextEditingController _outfit;
  late final TextEditingController _mood;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final relationship = ref
        .read(appControllerProvider)
        .data
        .relationships
        .where((e) => e.id == widget.relationshipId)
        .firstOrNull;
    final scene = relationship?.scene;
    _location = TextEditingController(text: scene?.location ?? '');
    _time = TextEditingController(text: scene?.timeHint ?? '');
    _outfit = TextEditingController(text: scene?.outfit ?? '');
    _mood = TextEditingController(text: scene?.mood ?? '');
    _notes = TextEditingController(text: scene?.notes ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_location, _time, _outfit, _mood, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data;
    final relationship = data.relationships
        .where((e) => e.id == widget.relationshipId)
        .firstOrNull;
    if (relationship == null) {
      return const DtDetailPage(
        title: '当前场景',
        child: Center(child: Text('关系不存在')),
      );
    }
    return DtDetailPage(
      title: '当前场景',
      subtitle: '场景只影响本轮剧情，不会覆盖长期关系与记忆',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              children: [
                DtTextField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: '地点'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _time,
                  decoration: const InputDecoration(labelText: '时间'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _outfit,
                  decoration: const InputDecoration(labelText: '穿着'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _mood,
                  decoration: const InputDecoration(labelText: '氛围'),
                ),
                const SizedBox(height: 12),
                DtTextField(
                  controller: _notes,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '剧情备注',
                    hintText: '未完成事件、情绪状态、本轮必须延续的细节……',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: '保存当前场景',
            onPressed: () {
              final updated = relationship.copyWith(
                scene: relationship.scene.copyWith(
                  location: _location.text.trim(),
                  timeHint: _time.text.trim(),
                  outfit: _outfit.text.trim(),
                  mood: _mood.text.trim(),
                  notes: _notes.text.trim(),
                ),
                updatedAt: DateTime.now(),
              );
              ref
                  .read(appControllerProvider.notifier)
                  .updateRelationship(updated);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          DtButton(
            label: '重置场景但保留关系记忆',
            variant: DtButtonVariant.secondary,
            onPressed: () {
              final updated = relationship.copyWith(
                scene: relationship.scene.copyWith(
                  location: '新的场景',
                  timeHint: '此刻',
                  outfit: '',
                  mood: '平静',
                  notes: '',
                ),
                updatedAt: DateTime.now(),
              );
              ref
                  .read(appControllerProvider.notifier)
                  .updateRelationship(updated);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

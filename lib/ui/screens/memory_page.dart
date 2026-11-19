import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  String _query = '';
  MemoryType? _filter;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider).data;
    final relationship = data.relationships
        .where((e) => e.id == widget.relationshipId)
        .firstOrNull;
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    final memories =
        data.memories.where((memory) {
          if (memory.relationshipId != widget.relationshipId) return false;
          if (_filter != null && memory.type != _filter) return false;
          if (_query.trim().isEmpty) return true;
          final q = _query.toLowerCase();
          return memory.title.toLowerCase().contains(q) ||
              memory.content.toLowerCase().contains(q);
        }).toList()..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DtDetailPage(
      title: '记忆',
      subtitle: character == null ? '关系记忆' : '${character.name} 记得什么',
      actions: [
        IconButton(
          onPressed: () => _showEditor(context, relation: relationship),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: '搜索固定记忆与共同经历',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: '全部',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final type in MemoryType.values) ...[
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: type.label,
                    selected: _filter == type,
                    onTap: () => setState(() => _filter = type),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: memories.isEmpty
                ? DtEmptyState(
                    icon: Icons.psychology_alt_rounded,
                    title: '还没有记忆',
                    body: '固定称呼、约定、共同经历和边界，角色才能长期保持一致。',
                    action: FilledButton.icon(
                      onPressed: () =>
                          _showEditor(context, relation: relationship),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('添加记忆'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: memories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final memory = memories[index];
                      return _MemoryCard(
                        memory: memory,
                        dark: dark,
                        onPin: () => ref
                            .read(appControllerProvider.notifier)
                            .toggleMemoryPinned(memory.id),
                        onEdit: () => _showEditor(
                          context,
                          relation: relationship,
                          existing: memory,
                        ),
                        onDelete: () => _confirmDelete(context, memory),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditor(
    BuildContext context, {
    required Relationship? relation,
    MemoryItem? existing,
  }) {
    if (relation == null) return;
    final title = TextEditingController(text: existing?.title ?? '');
    final content = TextEditingController(text: existing?.content ?? '');
    var type = existing?.type ?? MemoryType.userFact;
    var pinned = existing?.pinned ?? true;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '添加长期记忆' : '编辑记忆'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MemoryType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '类别'),
                  items: [
                    for (final item in MemoryType.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: content,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: '内容'),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: pinned,
                  onChanged: (value) => setDialogState(() => pinned = value),
                  title: const Text('固定记忆', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    '固定项会优先注入每次对话',
                    style: TextStyle(fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty && content.text.trim().isEmpty) {
                  return;
                }
                ref
                    .read(appControllerProvider.notifier)
                    .upsertMemory(
                      MemoryItem(
                        id: existing?.id ?? const Uuid().v4(),
                        relationshipId: relation.id,
                        type: type,
                        title: title.text.trim().isEmpty
                            ? '未命名记忆'
                            : title.text.trim(),
                        content: content.text.trim(),
                        createdAt: existing?.createdAt ?? DateTime.now(),
                        sourceThreadId: existing?.sourceThreadId,
                        sourceMessageId: existing?.sourceMessageId,
                        pinned: pinned,
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      title.dispose();
      content.dispose();
    });
  }

  Future<void> _confirmDelete(BuildContext context, MemoryItem memory) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记忆？'),
        content: Text('“${memory.title}”将从这段关系中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(appControllerProvider.notifier).deleteMemory(memory.id);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (dark ? const Color(0xFF28355D) : const Color(0xFFE8EEFF))
              : (dark ? DtColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (dark ? const Color(0xFF252B39) : const Color(0xFFE8ECF3)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (dark ? const Color(0xFFA2B3FF) : DtColors.brand)
                : null,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.dark,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
  });

  final MemoryItem memory;
  final bool dark;
  final VoidCallback onPin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(
        color: dark ? DtColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: memory.pinned
              ? DtColors.brand.withValues(alpha: 0.28)
              : (dark ? const Color(0xFF252B39) : const Color(0xFFE9EDF5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _typeColor(memory.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _typeIcon(memory.type),
              size: 18,
              color: _typeColor(memory.type),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        memory.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (memory.pinned)
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: DtColors.brand,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  memory.content,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '${memory.type.label} · ${DateFormat('M/d').format(memory.createdAt)}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: dark
                            ? const Color(0xFF727B8F)
                            : const Color(0xFF9AA2B2),
                      ),
                    ),
                    if (memory.sourceMessageId != null) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '对话来源',
                        style: TextStyle(fontSize: 9.5, color: DtColors.violet),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 19),
            onSelected: (value) {
              if (value == 'pin') onPin();
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pin',
                child: Text(memory.pinned ? '取消固定' : '固定记忆'),
              ),
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(MemoryType type) => switch (type) {
    MemoryType.userFact => Icons.person_outline_rounded,
    MemoryType.relationship => Icons.favorite_border_rounded,
    MemoryType.experience => Icons.auto_stories_outlined,
    MemoryType.promise => Icons.handshake_outlined,
    MemoryType.emotion => Icons.mood_outlined,
    MemoryType.scene => Icons.place_outlined,
    MemoryType.boundary => Icons.shield_outlined,
  };

  Color _typeColor(MemoryType type) => switch (type) {
    MemoryType.userFact => DtColors.brand,
    MemoryType.relationship => DtColors.rose,
    MemoryType.experience => DtColors.violet,
    MemoryType.promise => DtColors.mint,
    MemoryType.emotion => const Color(0xFFE5A33D),
    MemoryType.scene => const Color(0xFF6E8BB9),
    MemoryType.boundary => DtColors.coral,
  };
}

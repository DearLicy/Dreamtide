import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final threads = [...data.threads]
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final filtered = threads.where((thread) {
      if (_query.trim().isEmpty) return true;
      final character = data.characterForRelationship(
        data.relationshipForThread(thread) ?? data.relationships.first,
      );
      return thread.title.toLowerCase().contains(_query.toLowerCase()) ||
          (character?.intro.toLowerCase().contains(_query.toLowerCase()) ??
              false);
    }).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: DtStagger(
              child: DtPageHeader(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                leading: _OwnerAvatarButton(owner: data.owner),
                title: data.owner.displayName,
                subtitle: '${data.owner.status} · 今天也要记得照顾自己',
                actions: [
                  DtIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '新建对话',
                    onTap: () => _showQuickActions(context, ref),
                    soft: true,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DtStagger(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '搜索消息与角色',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DtStagger(
              index: 2,
              child: _PresenceStrip(
                count: data.relationships.length,
                onTap: () => context.go('/contacts'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: DtEmptyState(
                icon: Icons.nights_stay_rounded,
                title: '还没有找到对话',
                body: '创建角色，或换一个关键词再试试。',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final thread = filtered[index];
                  final relationship = data.relationshipForThread(thread);
                  final character = relationship == null
                      ? null
                      : data.characterForRelationship(relationship);
                  if (relationship == null || character == null) {
                    return const SizedBox.shrink();
                  }
                  final lastMessage = _lastMessage(data, thread.id);
                  final unread = thread.unread;
                  return DtStagger(
                    key: ValueKey('thread-${thread.id}'),
                    index: index,
                    child: _ConversationTile(
                      thread: thread,
                      relationship: relationship,
                      character: character,
                      lastMessage: lastMessage,
                      unread: unread,
                      dark: dark,
                      onTap: () {
                        ref
                            .read(appControllerProvider.notifier)
                            .markThreadRead(thread.id);
                        context.push('/chat/${thread.id}');
                      },
                      onLongPress: () =>
                          _showThreadActions(context, ref, thread),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Message? _lastMessage(AppData data, String threadId) {
    final list = data.messages.where((e) => e.threadId == threadId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list.isEmpty ? null : list.last;
  }

  void _showQuickActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: '发起新对话',
                subtitle: '选择一个已有角色',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/contacts');
                },
              ),
              DtSettingRow(
                icon: Icons.person_add_alt_1_rounded,
                title: '创建角色',
                subtitle: '设计新的梦境人物',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/character/new');
                },
              ),
              DtSettingRow(
                icon: Icons.groups_2_outlined,
                title: '创建群聊',
                subtitle: '多角色群聊将在 V2.2 开放',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('群聊将在 V2.2 开放')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThreadActions(
    BuildContext context,
    WidgetRef ref,
    ChatThread thread,
  ) {
    final controller = ref.read(appControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.push_pin_outlined,
                title: thread.pinned ? '取消置顶' : '置顶对话',
                onTap: () {
                  controller.toggleThreadPinned(thread.id);
                  Navigator.pop(context);
                },
              ),
              DtSettingRow(
                icon: thread.muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                title: thread.muted ? '恢复提醒' : '消息免打扰',
                onTap: () {
                  controller.toggleThreadMuted(thread.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerAvatarButton extends StatelessWidget {
  const _OwnerAvatarButton({required this.owner});

  final OwnerProfile owner;

  @override
  Widget build(BuildContext context) {
    return DtPressable(
      onTap: () => Scaffold.of(context).openDrawer(),
      semanticLabel: '打开个人资料',
      child: DtAvatar(
        name: owner.displayName,
        color: owner.avatarColor,
        size: 42,
        showStatus: true,
      ),
    );
  }
}

class _PresenceStrip extends StatelessWidget {
  const _PresenceStrip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DtSurface(
        level: DtSurfaceLevel.raised,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 20,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF42C58A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42C58A).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count 段关系正在等待你的回应',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '查看角色',
              style: TextStyle(
                color: dark ? const Color(0xFFE6DED0) : DtColors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: dark ? const Color(0xFFB9B1A3) : DtColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.thread,
    required this.relationship,
    required this.character,
    required this.lastMessage,
    required this.unread,
    required this.dark,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatThread thread;
  final Relationship relationship;
  final Character character;
  final Message? lastMessage;
  final int unread;
  final bool dark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final subtitle = lastMessage?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return DtSurface(
      level: thread.pinned ? DtSurfaceLevel.floating : DtSurfaceLevel.raised,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 20,
      backgroundColor: thread.pinned
          ? (dark ? const Color(0xFF24211C) : const Color(0xFFFFFCF5))
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DtAvatar(
                name: character.name,
                color: character.avatarColor,
                size: 50,
                heroTag: 'character-${character.id}',
              ),
              if (unread > 0)
                Positioned(
                  right: -3,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DtColors.coral,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: dark ? DtColors.darkBg : DtColors.mist,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        character.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(thread.updatedAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? const Color(0xFF727B90)
                            : const Color(0xFF9AA2B2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (thread.muted) ...[
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 13,
                        color: dark
                            ? const Color(0xFF737C91)
                            : const Color(0xFFA1A8B7),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        subtitle == null || subtitle.isEmpty
                            ? '开始一段新的对话'
                            : '${lastMessage!.fromAi ? '' : '你：'}$subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: dark
                              ? const Color(0xFF949DB1)
                              : const Color(0xFF7B8396),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DtColors.violet.withValues(
                          alpha: dark ? 0.16 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        relationship.stage,
                        style: const TextStyle(
                          color: DtColors.violet,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '心动 ${relationship.metrics['心动'] ?? 0}',
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFF727B90)
                            : const Color(0xFF9AA2B2),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return DateFormat('HH:mm').format(value);
    }
    if (now.difference(value).inDays == 1) return '昨天';
    return DateFormat('M/d').format(value);
  }
}

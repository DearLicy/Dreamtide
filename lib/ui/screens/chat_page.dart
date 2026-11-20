import '../components/dt_sheet.dart';
import '../components/dt_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/dialogue.dart';
import 'package:forui/forui.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _nearBottom = true;
  String _lastContent = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appControllerProvider.notifier).markThreadRead(widget.threadId);
      _jumpToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final near =
        _scrollController.position.maxScrollExtent - _scrollController.offset <
        80;
    if (near != _nearBottom) setState(() => _nearBottom = near);
  }

  void _jumpToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated && !DtMotion.reduced(context)) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final thread = data.threads
        .where((e) => e.id == widget.threadId)
        .firstOrNull;
    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('会话不存在')),
        body: const Center(child: Text('这段梦境已经找不到。')),
      );
    }
    final relationship = data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (relationship == null || character == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('会话异常')),
        body: const Center(child: Text('会话缺少角色关系。')),
      );
    }
    final messages =
        data.messages
            .where((e) => e.threadId == thread.id && e.isRenderable)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final content = '${messages.length}:${messages.lastOrNull?.text ?? ''}';
    if (content != _lastContent) {
      _lastContent = content;
      if (_nearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _nearBottom) _jumpToBottom(animated: false);
        });
      }
    }
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: dark ? DtColors.darkBg : DtColors.canvas,
      appBar: _ChatAppBar(
        character: character,
        relationship: relationship,
        onBack: context.pop,
        onMenu: () => _showChatMenu(context, data, relationship, character),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                  itemCount:
                      messages.length +
                      (state.generatingThreadId == thread.id ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= messages.length) {
                      return _TypingIndicator(character: character);
                    }
                    final message = messages[index];
                    final previous = index == 0 ? null : messages[index - 1];
                    final showTime =
                        previous == null ||
                        message.createdAt
                                .difference(previous.createdAt)
                                .inMinutes >=
                            12;
                    return DtStagger(
                      key: ValueKey('message-${message.id}'),
                      offset: 8,
                      child: Column(
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? DtColors.darkSurface
                                      : DtColors.surface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  _timeLabel(message.createdAt),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: dark
                                        ? const Color(0xFF817A70)
                                        : DtColors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          _MessageBubble(
                            message: message,
                            character: character,
                            owner: data.owner,
                            onLongPress: () => _showMessageActions(
                              context,
                              message,
                              relationship,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (!_nearBottom && messages.isNotEmpty)
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: DtPressable(
                      onTap: _jumpToBottom,
                      semanticLabel: '回到最新消息',
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: dark
                              ? DtColors.darkElevated
                              : DtColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: DtShadows.floating(dark),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: dark ? const Color(0xFFF0ECE4) : DtColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _ChatComposer(
            controller: _textController,
            focusNode: _focusNode,
            generating: state.generatingThreadId == thread.id,
            onSend: () async {
              if (_sending) return;
              final text = _textController.text;
              if (text.trim().isEmpty) return;
              _sending = true;
              final controller = ref.read(appControllerProvider.notifier);
              final future = controller.sendMessage(
                thread.id,
                text,
                onAccepted: () {
                  if (!mounted) return;
                  _sending = false;
                  if (_textController.text == text) _textController.clear();
                  _nearBottom = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _jumpToBottom(animated: false);
                  });
                },
              );
              await future;
              if (!mounted) return;
              _sending = false;
              final after = ref.read(appControllerProvider);
              if (after.error != null && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(after.error!)));
              }
            },
            onCancel: () =>
                ref.read(appControllerProvider.notifier).interruptGeneration(),
            onMore: () => _showMoreActions(context, relationship),
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
    return DateFormat('M月d日 HH:mm').format(value);
  }

  void _showChatMenu(
    BuildContext context,
    AppData data,
    Relationship relationship,
    Character character,
  ) {
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.person_outline_rounded,
                title: '查看角色资料',
                subtitle: character.intro,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/character/${character.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.psychology_alt_outlined,
                title: '记忆管理',
                subtitle: '角色真正记住的事',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/memory/${relationship.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.movie_filter_outlined,
                title: '导演模式',
                subtitle: '节奏、旁白与剧情推进',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/director/${relationship.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.shield_outlined,
                title: '内容与边界',
                subtitle:
                    '${relationship.consent.ceiling.label} · 安全词 ${relationship.consent.safeWord}',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/consent/${relationship.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context, Relationship relationship) {
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.movie_filter_outlined,
                iconColor: DtColors.brand,
                title: '当前场景',
                subtitle: relationship.scene.location,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/scene/${relationship.id}');
                },
              ),
              DtSettingRow(
                icon: Icons.psychology_outlined,
                iconColor: DtColors.mint,
                title: '添加一条记忆',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/memory/${relationship.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(
    BuildContext context,
    Message message,
    Relationship relationship,
  ) {
    showDtSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DtSettingRow(
                icon: Icons.copy_rounded,
                title: '复制文本',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制')));
                },
              ),
              DtSettingRow(
                icon: Icons.bookmark_add_outlined,
                iconColor: DtColors.violet,
                title: '存为记忆',
                onTap: () {
                  Navigator.pop(context);
                  _showMemoryDialog(context, message, relationship);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemoryDialog(
    BuildContext context,
    Message message,
    Relationship relationship,
  ) {
    final title = TextEditingController(text: '从对话中记住');
    final content = TextEditingController(text: message.text);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加长期记忆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DtTextField(
              controller: title,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 10),
            DtTextField(
              controller: content,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: '内容'),
            ),
          ],
        ),
        actions: [
          DtActionButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          DtActionButton.primary(
            onPressed: () {
              ref
                  .read(appControllerProvider.notifier)
                  .upsertMemory(
                    MemoryItem(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      relationshipId: relationship.id,
                      type: MemoryType.experience,
                      title: title.text.trim().isEmpty
                          ? '对话记忆'
                          : title.text.trim(),
                      content: content.text.trim(),
                      createdAt: DateTime.now(),
                      sourceThreadId: message.threadId,
                      sourceMessageId: message.id,
                      pinned: true,
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).whenComplete(() {
      title.dispose();
      content.dispose();
    });
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.character,
    required this.relationship,
    required this.onBack,
    required this.onMenu,
  });

  final Character character;
  final Relationship relationship;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 44,
      leading: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: DtIconButton(
          onTap: onBack,
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: '返回',
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          DtAvatar(
            name: character.name,
            color: character.avatarColor,
            size: 39,
            showStatus: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${relationship.stage} · ${relationship.consent.ceiling.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: dark
                        ? const Color(0xFF8A93A7)
                        : const Color(0xFF8B94A5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        DtIconButton(onTap: onMenu, icon: Icons.menu_rounded, tooltip: '更多'),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.7),
        child: Divider(
          height: 0.7,
          color: dark ? DtColors.darkLine : const Color(0xFFE9E3DA),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.character,
    required this.owner,
    required this.onLongPress,
  });
  final Message message;
  final Character character;
  final OwnerProfile owner;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) {
    if (!message.isRenderable) return const SizedBox.shrink();
    final mine = !message.fromAi;
    final segments = mine
        ? [
            DialogueSegment(
              kind: DialogueSegmentKind.speech,
              text: message.text,
            ),
          ]
        : DialogueParser.parse(message.text);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (final segment in segments)
          if (segment.kind == DialogueSegmentKind.narration)
            DtPressable(
              onLongPress: onLongPress,
              child: Padding(
                key: const ValueKey('message-narration'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                child: Text(
                  segment.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: DtColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: mine
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine) ...[
                    DtAvatar(
                      name: character.name,
                      color: character.avatarColor,
                      size: 36,
                    ),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .73,
                      ),
                      child: DtPressable(
                        onLongPress: onLongPress,
                        semanticLabel: '长按消息操作',
                        child: Container(
                          key: const ValueKey('message-speech'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? DtColors.violet
                                : (dark
                                      ? DtColors.darkSurface
                                      : DtColors.surface),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            segment.text,
                            style: TextStyle(
                              color: mine
                                  ? Colors.white
                                  : (dark
                                        ? const Color(0xFFEEEEF2)
                                        : DtColors.ink),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 9),
                    DtAvatar(
                      name: owner.displayName,
                      color: owner.avatarColor,
                      size: 36,
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.character});
  final Character character;
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      '正在输入…',
      style: TextStyle(fontSize: 12, color: DtColors.textSecondary),
    ),
  );
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.generating,
    required this.onSend,
    required this.onCancel,
    required this.onMore,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? DtColors.darkSurface : DtColors.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DtTextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '说点什么……',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final empty = value.text.trim().isEmpty;
                return DtIconButton(
                  icon: generating
                      ? empty
                            ? Icons.stop_rounded
                            : FIcons.send
                      : empty
                      ? FIcons.plus
                      : FIcons.send,
                  tooltip: generating
                      ? empty
                            ? '停止生成'
                            : '发送并打断当前回复'
                      : empty
                      ? '更多功能'
                      : '发送',
                  onTap: generating
                      ? empty
                            ? onCancel
                            : onSend
                      : empty
                      ? onMore
                      : onSend,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

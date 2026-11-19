import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_avatar.dart';
import '../components/dt_controls.dart';
import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';

class MomentsPage extends ConsumerWidget {
  const MomentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final data = state.data;
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                leading: DtPressable(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  semanticLabel: '打开个人资料',
                  child: DtAvatar(
                    name: data.owner.displayName,
                    color: data.owner.avatarColor,
                    size: 42,
                    showStatus: true,
                  ),
                ),
                title: '动态',
                subtitle: '梦境空间 · 只有你和角色们',
                actions: [
                  DtIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: '发布动态',
                    onTap: () => _showComposer(context, ref),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: _SpaceHero(onTap: () => _showComposer(context, ref)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
            sliver: SliverList.separated(
              itemCount: data.moments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final moment = data.moments[index];
                return DtStagger(
                  key: ValueKey('moment-${moment.id}'),
                  index: index,
                  child: _MomentCard(
                    moment: moment,
                    ownerName: data.owner.displayName,
                    dark: dark,
                    onLike: () => ref
                        .read(appControllerProvider.notifier)
                        .toggleMomentLike(moment.id, data.owner.displayName),
                    onComment: () => _showCommentSheet(context, ref, moment),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showComposer(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '发布到梦境空间',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('图片与视频将在后续版本开放。', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(hintText: '这一刻想留下什么？'),
            ),
            const SizedBox(height: 12),
            DtButton(
              label: '发布',
              icon: Icons.arrow_upward_rounded,
              onPressed: () {
                ref
                    .read(appControllerProvider.notifier)
                    .publishMoment(controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _showCommentSheet(BuildContext context, WidgetRef ref, Moment moment) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '评论 · ${moment.authorName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (moment.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('还没有评论，说点什么吧。'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: moment.comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = moment.comments[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${comment.authorName}：',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              comment.content,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '写下评论'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DtButton(
                    label: '发送',
                    compact: true,
                    fullWidth: false,
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .addMomentComment(moment.id, controller.text);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}

class _SpaceHero extends StatelessWidget {
  const _SpaceHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtSurface(
      level: DtSurfaceLevel.floating,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      borderRadius: 22,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DtColors.brand, DtColors.violet],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '梦境空间',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  '只有你和角色们能看到的空间',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A93A4)),
                ),
              ],
            ),
          ),
          DtPressable(
            onTap: onTap,
            semanticLabel: '发布到梦境空间',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF312C24) : DtColors.surfaceMuted,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: dark ? const Color(0xFFF2ECE2) : DtColors.ink,
                    size: 15,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '发布',
                    style: TextStyle(
                      color: dark ? const Color(0xFFF2ECE2) : DtColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.ownerName,
    required this.dark,
    required this.onLike,
    required this.onComment,
  });

  final Moment moment;
  final String ownerName;
  final bool dark;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final liked = moment.likedBy.contains(ownerName);
    return DtSurface(
      level: DtSurfaceLevel.raised,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DtAvatar(
                name: moment.authorName,
                color: moment.avatarColor,
                size: 44,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          moment.authorName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (moment.fromAi) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: DtColors.violet.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                color: DtColors.violet,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _time(moment.createdAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? const Color(0xFF737C91)
                            : const Color(0xFF9AA2B2),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: dark ? const Color(0xFF6A7388) : const Color(0xFFA5ACBA),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            moment.content,
            style: const TextStyle(fontSize: 14.5, height: 1.65),
          ),
          const SizedBox(height: 12),
          Divider(
            color: dark ? const Color(0xFF242938) : const Color(0xFFEFF2F7),
          ),
          Row(
            children: [
              DtPressable(
                onTap: onLike,
                semanticLabel: liked ? '取消点赞' : '点赞',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: liked
                            ? DtColors.coral
                            : (dark
                                  ? const Color(0xFF8A93A7)
                                  : const Color(0xFF7E8798)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        moment.likedBy.isEmpty
                            ? '喜欢'
                            : '${moment.likedBy.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark
                              ? const Color(0xFF8A93A7)
                              : const Color(0xFF7E8798),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DtPressable(
                onTap: onComment,
                semanticLabel: '评论',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                        color: dark
                            ? const Color(0xFF8A93A7)
                            : const Color(0xFF7E8798),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        moment.comments.isEmpty
                            ? '评论'
                            : '${moment.comments.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark
                              ? const Color(0xFF8A93A7)
                              : const Color(0xFF7E8798),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (moment.likedBy.isNotEmpty)
                Text(
                  _likeSummary(moment.likedBy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: dark
                        ? const Color(0xFF6E778C)
                        : const Color(0xFF9CA4B3),
                  ),
                ),
            ],
          ),
          if (moment.comments.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1A1F2D) : const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final comment in moment.comments.take(2))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${comment.authorName}：',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: comment.content),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: dark
                              ? const Color(0xFFB3BCCF)
                              : const Color(0xFF596174),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) return '昨天 ${DateFormat('HH:mm').format(value)}';
    return DateFormat('M月d日 HH:mm').format(value);
  }

  String _likeSummary(List<String> names) {
    if (names.length <= 2) return names.join('、');
    return '${names.take(2).join('、')} 等 ${names.length} 人';
  }
}

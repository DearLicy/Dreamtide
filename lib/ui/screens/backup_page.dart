import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    return DtDetailPage(
      title: '数据与备份',
      subtitle: 'V2 数据只保存在本机或浏览器',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DtSettingRow(
                  icon: Icons.copy_all_outlined,
                  title: '复制完整备份',
                  subtitle: '复制 JSON 到剪贴板，不包含 API Key',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: controller.exportBackup()),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('备份 JSON 已复制')),
                      );
                    }
                  },
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.restore_outlined,
                  iconColor: DtColors.violet,
                  title: '从 JSON 恢复',
                  subtitle: '覆盖当前本机数据',
                  onTap: () => _showImport(context, ref),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.refresh_rounded,
                  iconColor: DtColors.coral,
                  title: '重置为演示数据',
                  subtitle: '清空当前 V2 数据',
                  onTap: () => _confirmReset(context, controller),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: DtColors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DtColors.brand,
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Web 数据保存在浏览器本地存储中。清理站点数据、隐私模式结束或浏览器迁移可能造成丢失；请定期复制备份。',
                    style: TextStyle(fontSize: 11.5, height: 1.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImport(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 JSON 恢复'),
        content: TextField(
          controller: controller,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(
            hintText: '粘贴 dreamtide V2 备份 JSON',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(appControllerProvider.notifier)
                    .importBackup(controller.text);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('恢复成功')));
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('恢复失败：$error')));
                }
              }
            },
            child: const Text('覆盖恢复'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _confirmReset(
    BuildContext context,
    AppController controller,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置全部 V2 数据？'),
        content: const Text('当前角色、关系、消息、记忆与动态都会被清空，并恢复演示数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.resetDemo();
  }
}

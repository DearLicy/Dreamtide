import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final settings = state.data.settings;
    return DtDetailPage(
      title: '设置',
      subtitle: '只保存在本机',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          DtSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DtSettingRow(
                  icon: Icons.person_outline_rounded,
                  title: '个人资料',
                  subtitle: state.data.owner.displayName,
                  onTap: () => context.push('/profile'),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.hub_outlined,
                  title: '模型与供应商',
                  subtitle:
                      '${settings.provider.model} · ${state.hasApiKey ? '已配置密钥' : '演示模式'}',
                  onTap: () => context.push('/provider'),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: DtColors.violet,
                  title: '梦设管理',
                  subtitle: '${state.data.personas.length} 套梦设',
                  onTap: () => context.push('/personas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DtSettingRow(
                  icon: Icons.dark_mode_outlined,
                  title: '外观',
                  subtitle: switch (settings.themeMode) {
                    AppThemeMode.system => '跟随系统',
                    AppThemeMode.light => '浅色',
                    AppThemeMode.dark => '深色',
                  },
                  trailing: DropdownButton<AppThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: AppThemeMode.system,
                        child: Text('系统'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeMode.light,
                        child: Text('浅色'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeMode.dark,
                        child: Text('深色'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.setTheme(value);
                    },
                  ),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.shield_outlined,
                  iconColor: DtColors.coral,
                  title: '隐私与安全',
                  subtitle: '全局内容上限：${settings.contentCeiling.label}',
                  onTap: () => context.push('/safety'),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.backup_outlined,
                  iconColor: DtColors.mint,
                  title: '数据与备份',
                  subtitle: 'JSON 导出、恢复与演示重置',
                  onTap: () => context.push('/backup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DtSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                DtSettingRow(
                  icon: Icons.info_outline_rounded,
                  title: '关于 Dreamtide',
                  subtitle: 'V2.0.0 · 本地优先 AI 梦境恋爱 IM',
                  onTap: () => context.push('/about'),
                ),
                const Divider(indent: 62),
                DtSettingRow(
                  icon: Icons.route_outlined,
                  iconColor: DtColors.violet,
                  title: '版本路线',
                  subtitle: 'V2.1 生活模拟 · V2.2 群聊 · V2.3 媒体',
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

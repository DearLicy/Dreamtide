import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../components/dt_controls.dart';
import '../components/dt_detail_page.dart';
import '../theme/dt_theme.dart';

class ProviderPage extends ConsumerStatefulWidget {
  const ProviderPage({super.key});

  @override
  ConsumerState<ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends ConsumerState<ProviderPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late ProviderKind _kind;
  late bool _remember;
  bool _obscure = true;
  DtButtonStatus _saveStatus = DtButtonStatus.idle;

  @override
  void initState() {
    super.initState();
    final provider = ref.read(appControllerProvider).data.settings.provider;
    _baseUrl = TextEditingController(text: provider.baseUrl);
    _model = TextEditingController(text: provider.model);
    _apiKey = TextEditingController();
    _kind = provider.kind;
    _remember = provider.rememberKey;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtDetailPage(
      title: '模型与供应商',
      subtitle: 'BYOK · 请求直接发送到你填写的地址',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DtSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '协议',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DtSegmentedControl(
                  labels: const ['OpenAI 兼容', 'Anthropic'],
                  index: _kind == ProviderKind.openaiCompatible ? 0 : 1,
                  onChanged: (value) => setState(
                    () => _kind = value == 0
                        ? ProviderKind.openaiCompatible
                        : ProviderKind.anthropic,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _baseUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    hintText: 'gpt-4.1-mini',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: state.hasApiKey
                        ? 'API Key（留空则保留当前密钥）'
                        : 'API Key',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SwitchListTile(
                  value: _remember,
                  onChanged: (value) => setState(() => _remember = value),
                  title: const Text('记住密钥', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    kIsWeb
                        ? '关闭时仅在当前浏览器标签页使用；开启后写入浏览器本地存储，安全性有限。'
                        : '关闭时密钥仅在当前会话使用；开启后写入系统安全存储。',
                    style: const TextStyle(fontSize: 10.5, height: 1.4),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (dark ? const Color(0xFF252035) : const Color(0xFFFFF5EC)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE7A55D).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE29A45),
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '对话内容会发送给你配置的模型供应商。Dreamtide 不经过自有服务器，也无法替供应商决定其数据处理方式。',
                    style: TextStyle(fontSize: 11.5, height: 1.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DtButton(
            label: '保存供应商设置',
            status: _saveStatus,
            loadingText: '正在保存…',
            successText: '已保存',
            onPressed: () async {
              if (_saveStatus != DtButtonStatus.idle) return;
              setState(() => _saveStatus = DtButtonStatus.loading);
              try {
                await ref
                    .read(appControllerProvider.notifier)
                    .saveProvider(
                      config: state.data.settings.provider.copyWith(
                        kind: _kind,
                        baseUrl: _baseUrl.text.trim(),
                        model: _model.text.trim(),
                        rememberKey: _remember,
                      ),
                      apiKey: _apiKey.text.trim().isEmpty
                          ? null
                          : _apiKey.text.trim(),
                    );
                if (!mounted) return;
                setState(() => _saveStatus = DtButtonStatus.success);
                await Future<void>.delayed(const Duration(milliseconds: 320));
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (!context.mounted) return;
                setState(() => _saveStatus = DtButtonStatus.idle);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
              }
            },
          ),
          if (state.hasApiKey) ...[
            const SizedBox(height: 8),
            DtButton(
              label: '清除已保存的 API Key',
              variant: DtButtonVariant.secondary,
              compact: true,
              onPressed: () async {
                await ref
                    .read(appControllerProvider.notifier)
                    .clearProviderKey();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API Key 已从本机清除')),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '未配置密钥时，对话使用本地演示回复，便于检查 UI 与交互。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: dark ? const Color(0xFF898176) : DtColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

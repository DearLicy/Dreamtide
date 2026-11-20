# 构建与 GitHub 发布

Dreamtide 只通过 GitHub 分发，不上架应用商店。

## Android

```bash
flutter build apk --release --split-per-abi
```

产物：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

CI 使用调试签名只用于公开测试构建。正式长期更新应先配置独立 Android release keystore，并把 Base64 或文件内容保存在 GitHub Actions Secrets 中，禁止提交到仓库。

## iOS 自签

GitHub Release 提供 unsigned IPA。用户自签流程：

1. 安装 iLoader；
2. 在 iLoader 中安装 LiveContainer 与 SideStore；
3. 导入 `Dreamtide-unsigned.ipa`；
4. 使用自己的 Apple ID 完成签名；
5. 按 SideStore 提示完成续签。

构建命令：

```bash
flutter build ios --release --no-codesign
```

把 `Runner.app` 放入 `Payload/`，压缩为 `Dreamtide-unsigned.ipa`：

```bash
mkdir -p .tmp/ipa/Payload
cp -R build/ios/iphoneos/Runner.app .tmp/ipa/Payload/
cd .tmp/ipa
zip -qry ../../build/Dreamtide-unsigned.ipa Payload
cd ../..
```

所有中间文件只放在 `.tmp/`。不要使用系统 `/tmp`。

## Web

```bash
flutter build web --release --base-href "/Dreamtide/"
```

GitHub Pages 发布 `build/web`。Web 是完整 BYOK 客户端，但受浏览器本地存储、CORS 与第三方供应商接口差异限制。

## Release 内容

每个 GitHub Release 应包含：

- Android APK 文件；
- `Dreamtide-unsigned.ipa`；
- `SHA256SUMS.txt`；
- 自签安装说明；
- 版本更新日志；
- Web 构建来源版本。

## 本地工具

本仓库约定：

- `TMPDIR=<仓库路径>/.tmp`
- Gradle 缓存可以使用现有系统缓存，但禁止把构建产物写入系统 `/tmp`
- 不创建功能分支，直接提交并推送 `main`

## V2.0.1 更新

- 首次安装为空白状态，不内置梦设、角色、会话、记忆或动态。删除本地演示回复、模拟角色点赞与评论。
- 默认 DeepSeek 官方；拉取真实模型列表后选择保存，未配置时保留聊天草稿。
- AI 括号动作与 V1 Markdown 旁白显示在气泡外，过滤空内容和协议残留。
- 主要交互控件切换至 Forui，降低圆角、阴影与动效强度，弹层完整覆盖底栏。
- 清空数据同步删除密钥，并阻止未完成的旧回复重新写回。

旧版本中已经保存的数据不会被更新静默删除。如需从空白状态开始，请先自行备份，再在「数据与备份」中清空。

## V2.0.2 更新

- OpenAI 兼容聊天默认不再发送 `max_tokens`，避免推理模型先耗尽内部推理额度后返回空正文；兼容 SSE、普通 JSON 和 `reasoning_content` 流式响应。
- 移除正文硬截断；回复长度改由本轮回复计划引导。
- 失败请求可直接重试上一条，最新角色回复可重新生成，不重复用户消息。
- 新增相册与相机图片消息、发送前预览和可选说明文字；原生附件写入应用私有目录，Web 附件写入 IndexedDB，不把图片 Base64 写入主数据库。

## V2.0.3 更新

- 正常对话完成后自动结算好感、信任、心动、张力和关系阶段，关系页展示上轮数值变化、原因与累计互动轮数。
- 同一条用户消息重新生成、重试不会重复增加关系数值。
- 最近角色表达会作为反复读提示注入；生成结果与近期回复高度相似时静默重写一次。

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

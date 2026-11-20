# Dreamtide V2 架构

## 技术路线

Flutter 负责 Android、iOS、Web 的主 UI 与产品交互。Kotlin/Swift 承担只有平台侧才能可靠提供的能力，例如通知调度、安全存储、生物识别、应用锁、截图保护、文件和音频。

不做三套独立 UI 客户端。体验按真实启动、滚动、输入、转场和后台行为验收，不以是否使用原生控件作为唯一标准。

## 目录

| 目录 | 职责 |
| --- | --- |
| `lib/domain` | 产品实体、枚举和序列化 |
| `lib/application` | Riverpod 应用控制器、状态变更和持久化调度 |
| `lib/data` | SQLite / Web 本地存储、种子数据与密钥存储 |
| `lib/ai` | 提示词装配、记忆检索、SSE 供应商客户端 |
| `lib/router` | 三个根分支与全屏二级路由 |
| `lib/ui` | 设计令牌、共享组件、根页面与详情页面 |
| `lib/platform` | MethodChannel 原生桥接 |
| `android` / `ios` | Kotlin / Swift 原生平台模块 |

## 导航

`StatefulShellRoute.indexedStack` 只包裹：

- `/messages`
- `/contacts`
- `/moments`

聊天、角色、记忆、导演、场景、边界、设置、备份和关于均注册在 Shell 外，从路由结构上保证二级页面没有底部导航。

## 核心类型

- `LocalOwner`
- `UserPersona`
- `Character`
- `Relationship`
- `ChatThread`
- `Message`
- `MemoryItem`
- `SceneState`
- `DirectorConfig`
- `ConsentProfile`
- `Moment`
- `ProviderConfig`
- `AppData`

`ChatThread` 当前只开放单聊，但已经使用参与者列表和关系绑定，为 V2.2 群聊保留稳定结构。

## 提示词优先级

1. 不可覆盖的平台安全规则；
2. 用户硬边界、允许/禁止主题、安全词和暂停状态；
3. 梦设与角色稳定人设；
4. 关系状态与数值；
5. 当前场景和导演设置；
6. 固定与检索记忆；
7. 最近消息；
8. 本轮用户输入。

任何角色设定、场景亲密程度或导演指令都不能覆盖第 1、2 层。

## 记忆检索

V2.0 不引入向量数据库。检索顺序：

1. 边界记忆；
2. 固定记忆；
3. 与当前输入有词项重合的记忆；
4. 最近记忆。

原生 SQLite 同时维护 `memory_fts` 虚拟表，为后续搜索 UI 提供 FTS5 基础。

## 持久化

原生端当前使用 `sqflite` 保存版本化 `AppData` JSON 和 FTS5 记忆索引。Web 使用浏览器本地存储。

V2.0.2 计划在原生端接入 SQLCipher，并把应用锁、数据库密钥和截图保护统一到原生安全模块。当前 API Key 已在原生端进入系统安全存储，普通备份不包含密钥。

## AI 供应商

当前支持：

- OpenAI Chat Completions 兼容接口；
- Anthropic Messages 接口；
- SSE 流式增量；
- 错误统一收束为角色消息与可见错误提示。

请求路径：

```text
AppData + ChatThread + User input
      ↓
ContextAssembler
      ↓
Provider-specific SSE client
      ↓
Streaming Message updates
```

## 性能原则

- 聊天列表只渲染可显示消息；
- 空消息在进入控制器前过滤；
- 根页面使用分支状态保持；
- 动态与长列表使用 Sliver；
- 流式更新只改当前消息；
- 键盘使用 `resizeToAvoidBottomInset`，输入区固定安全区；
- 所有网络请求异步，不阻塞主线程持久化。

## 原生桥

当前 `com.dearlicy.dreamtide/platform` 提供：

- `platformName`；
- `setSecureScreen`。

Android 已启用 `FLAG_SECURE`。iOS 快照隐私遮罩、通知、生物识别、录音和本地生活调度按版本接入。

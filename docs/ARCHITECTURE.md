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
7. 当前会话的剧情连续性备忘；
8. 最近消息；
9. 本轮用户输入。

任何角色设定、场景亲密程度或导演指令都不能覆盖第 1、2 层。

## 记忆检索

V2.0 不引入向量数据库。检索顺序：

1. 边界记忆；
2. 固定记忆；
3. 与当前输入有词项重合的记忆；
4. 最近记忆。

原生 SQLite 同时维护 `memory_fts` 虚拟表，为后续搜索 UI 提供 FTS5 基础。

每个 `ChatThread` 另存独立的 `contextMemo` 和 `summarizedThroughMessageId`。每段对话累积到 12 条未整理消息后，在一次正常回复完成后客户端以同一 BYOK 供应商发起独立、非流式的静默整理请求；一次最多整理 16 条旧消息，并保留最近 8 条原文。它不显示在聊天里、不阻塞主回复，也不会在应用关闭后调用模型。工作记忆在摘要尚未建立前最多保留 24 条，稳定后回到最近 8 条原文（约 4 轮），避免摘要未返回时旧内容先从提示中消失。成功后摘要与覆盖游标一起写入本地数据，并在之后的主请求系统提示中使用。原消息不删除；摘要失败、空返回或会话重置都不会覆盖上一份有效备忘。

事实记忆只接受模型从输入消息 ID 中明确引用的来源；用户信息必须来自用户消息，用户边界只能由用户手动创建。自动整理对已有事实做增量合并，不静默清除用户已保存的记忆。记忆整理结果不回显到聊天；用户可以在关系记忆页查看、编辑或删除。

## 关系结算

成功回复后，`RelationshipDynamics` 根据本轮用户表达、图片事件和是否分享真实近况结算四项数值。正常交流至少会推动一项，冷淡回应会增加张力而不刷好感，恶意表达会降低好感并显著提高张力。数值越高增长越慢，综合分数决定关系阶段。`lastMetricDelta`、`lastMetricReason` 和 `interactionCount` 随关系持久化，关系页可直接查看。同一条用户消息重新生成不会重复结算。

## 重复回复防护

`RepetitionGuard` 对最近 6 条角色回复做归一化和字符二元组相似度比较；短句只拦截完全重复，长回复同时拦截高度相似的句式和内容。命中后使用同一 BYOK 供应商静默重写一次，只有明显不同的结果才会替换原回复。提示词同时列出最近 4 条角色表达作为“不要复用”的负空间。

摘要请求会把尚未整理的历史片段发送给用户当前配置的模型供应商；摘要不是只在设备上的模型推理。原始会话及摘要结果留在本地，原消息不因归纳而删除。

## 持久化

原生端当前使用 `sqflite` 保存版本化 `AppData` JSON 和 FTS5 记忆索引。Web 使用浏览器本地存储。

聊天图片通过独立 `AttachmentStore` 保存：原生端写入应用支持目录，Web 写入 IndexedDB。消息只保存不透明附件引用，避免把图片 Base64 塞进 SQLite/SharedPreferences。清空本地数据时同步清理附件库。

V2.0.2 计划在原生端接入 SQLCipher，并把应用锁、数据库密钥和截图保护统一到原生安全模块。当前 API Key 已在原生端进入系统安全存储，普通备份不包含密钥。

## AI 供应商

当前支持：

- OpenAI Chat Completions 兼容接口；
- Anthropic Messages 接口；
- SSE 流式增量；
- OpenAI 兼容流可识别 `delta.content`、完整 `message.content`、普通 JSON 回包和只包含 `reasoning_content` 的推理模型；
- OpenAI 兼容聊天默认省略 `max_tokens`，长度由提示词规划而非正文截断控制；
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

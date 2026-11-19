import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_client.dart';
import '../ai/context_assembler.dart';
import '../data/local_store.dart';
import '../data/local_store_factory.dart';
import '../data/provider_key_store.dart';
import '../data/seed_data.dart';
import '../domain/models.dart';

class ApplicationState {
  const ApplicationState({
    required this.data,
    this.loading = true,
    this.generatingThreadId,
    this.error,
    this.hasApiKey = false,
  });

  final AppData data;
  final bool loading;
  final String? generatingThreadId;
  final String? error;
  final bool hasApiKey;

  ApplicationState copyWith({
    AppData? data,
    bool? loading,
    String? generatingThreadId,
    bool clearGenerating = false,
    String? error,
    bool clearError = false,
    bool? hasApiKey,
  }) => ApplicationState(
    data: data ?? this.data,
    loading: loading ?? this.loading,
    generatingThreadId: clearGenerating
        ? null
        : (generatingThreadId ?? this.generatingThreadId),
    error: clearError ? null : (error ?? this.error),
    hasApiKey: hasApiKey ?? this.hasApiKey,
  );
}

final appControllerProvider =
    StateNotifierProvider<AppController, ApplicationState>((ref) {
      return AppController();
    });

final currentPersonaProvider = Provider<UserPersona?>((ref) {
  final data = ref.watch(appControllerProvider).data;
  return data.personaById(data.settings.currentPersonaId);
});

class AppController extends StateNotifier<ApplicationState> {
  AppController({
    LocalDataStore? store,
    ProviderKeyStore? keyStore,
    AiClient? aiClient,
  }) : _store = store ?? createLocalDataStore(),
       _keyStore = keyStore ?? ProviderKeyStore(),
       _aiClient = aiClient ?? AiClient(),
       super(ApplicationState(data: buildSeedData())) {
    _load();
  }

  final LocalDataStore _store;
  final ProviderKeyStore _keyStore;
  final AiClient _aiClient;
  final ContextAssembler _assembler = const ContextAssembler();
  final Uuid _uuid = const Uuid();
  Timer? _saveTimer;
  bool _hasApiKey = false;

  bool get hasApiKey => _hasApiKey;

  Future<void> _load() async {
    try {
      final loaded = await _store.load();
      final data = loaded ?? buildSeedData();
      final key = await _keyStore.read(
        persistent: data.settings.provider.rememberKey,
      );
      _hasApiKey = key?.trim().isNotEmpty ?? false;
      if (!mounted) return;
      state = state.copyWith(
        data: data,
        loading: false,
        clearError: true,
        hasApiKey: _hasApiKey,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: '本地数据读取失败：$error');
    }
  }

  void _commit(AppData data) {
    state = state.copyWith(data: data, clearError: true);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 180), () {
      unawaited(_persist(data));
    });
  }

  Future<void> _persist(AppData data) async {
    try {
      await _store.save(data);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: '保存失败：$error');
    }
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _store.save(state.data);
  }

  void confirmAdult() {
    _commit(
      state.data.copyWith(
        settings: state.data.settings.copyWith(
          ageConfirmed: true,
          onboardingComplete: true,
        ),
      ),
    );
  }

  void setTheme(AppThemeMode mode) {
    _commit(
      state.data.copyWith(
        settings: state.data.settings.copyWith(themeMode: mode),
      ),
    );
  }

  void setContentCeiling(ContentLevel level) {
    _commit(
      state.data.copyWith(
        settings: state.data.settings.copyWith(contentCeiling: level),
      ),
    );
  }

  void selectPersona(String personaId) {
    _commit(
      state.data.copyWith(
        settings: state.data.settings.copyWith(currentPersonaId: personaId),
      ),
    );
  }

  void updateOwner(OwnerProfile owner) {
    _commit(state.data.copyWith(owner: owner));
  }

  void upsertPersona(UserPersona persona) {
    final personas = [...state.data.personas];
    final index = personas.indexWhere((e) => e.id == persona.id);
    if (index >= 0) {
      personas[index] = persona;
    } else {
      personas.add(persona);
    }
    _commit(state.data.copyWith(personas: personas));
  }

  void upsertCharacter(Character character) {
    final characters = [...state.data.characters];
    final index = characters.indexWhere((e) => e.id == character.id);
    if (index >= 0) {
      characters[index] = character;
    } else {
      characters.add(character);
    }
    _commit(state.data.copyWith(characters: characters));
  }

  ChatThread addCharacterWithRelationship(Character character) {
    final data = state.data;
    final now = DateTime.now();
    final relationship = Relationship(
      id: 'rel_${character.id}',
      characterId: character.id,
      personaId: data.settings.currentPersonaId,
      stage: '刚刚相遇',
      nickname: '你',
      metrics: const {'好感': 12, '信任': 8, '心动': 10, '张力': 5},
      consent: const ConsentProfile(),
      scene: const SceneState(
        location: '梦境初次相遇的地方',
        timeHint: '刚刚开始',
        mood: '好奇、克制',
        notes: '这是这段关系的第一次对话。',
      ),
      updatedAt: now,
    );
    final thread = ChatThread(
      id: 'thread_${character.id}',
      relationshipId: relationship.id,
      type: ThreadType.direct,
      title: character.name,
      updatedAt: now,
      participantIds: [character.id],
    );
    final greeting = Message(
      id: _uuid.v4(),
      threadId: thread.id,
      senderId: character.id,
      senderName: character.name,
      text: character.greeting,
      createdAt: now,
      fromAi: true,
    );
    _commit(
      data.copyWith(
        characters: [...data.characters, character],
        relationships: [...data.relationships, relationship],
        threads: [...data.threads, thread],
        messages: [...data.messages, greeting],
      ),
    );
    return thread;
  }

  void markThreadRead(String threadId) {
    final threads = [
      for (final thread in state.data.threads)
        thread.id == threadId ? thread.copyWith(unread: 0) : thread,
    ];
    _commit(state.data.copyWith(threads: threads));
  }

  void toggleThreadPinned(String threadId) {
    final threads = [
      for (final thread in state.data.threads)
        thread.id == threadId
            ? thread.copyWith(pinned: !thread.pinned)
            : thread,
    ];
    _commit(state.data.copyWith(threads: threads));
  }

  void toggleThreadMuted(String threadId) {
    final threads = [
      for (final thread in state.data.threads)
        thread.id == threadId ? thread.copyWith(muted: !thread.muted) : thread,
    ];
    _commit(state.data.copyWith(threads: threads));
  }

  Future<void> saveProvider({
    required ProviderConfig config,
    String? apiKey,
  }) async {
    final effectiveKey = apiKey != null && apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : await _keyStore.read(
            persistent: state.data.settings.provider.rememberKey,
          );
    if (effectiveKey != null && effectiveKey.trim().isNotEmpty) {
      await _keyStore.write(
        effectiveKey.trim(),
        persistent: config.rememberKey,
      );
      _hasApiKey = true;
    }
    _commit(
      state.data.copyWith(
        settings: state.data.settings.copyWith(provider: config),
      ),
    );
    state = state.copyWith(hasApiKey: _hasApiKey);
  }

  Future<void> clearProviderKey() async {
    await _keyStore.clear();
    _hasApiKey = false;
    state = state.copyWith(hasApiKey: false);
  }

  Future<void> sendMessage(String threadId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.generatingThreadId != null) return;
    final data = state.data;
    final thread = data.threads.where((e) => e.id == threadId).firstOrNull;
    if (thread == null) return;
    final relationship = data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (relationship == null || character == null) return;

    if (trimmed.toLowerCase() == relationship.consent.safeWord.toLowerCase()) {
      final safetyMessage = Message(
        id: _uuid.v4(),
        threadId: threadId,
        senderId: character.id,
        senderName: character.name,
        text: '我在。已经停下来了。先不继续剧情，告诉我你现在需要安静、陪伴，还是结束这次场景。',
        createdAt: DateTime.now(),
        fromAi: true,
      );
      _appendMessages([safetyMessage], threadId, updateMetrics: false);
      return;
    }

    final prompt = _assembler.assemble(
      data: data,
      thread: thread,
      userInput: trimmed,
    );
    final userMessage = Message(
      id: _uuid.v4(),
      threadId: threadId,
      senderId: data.owner.id,
      senderName: data.owner.displayName,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _appendMessages([userMessage], threadId);
    state = state.copyWith(generatingThreadId: threadId, clearError: true);

    String? aiMessageId;
    try {
      final apiKey = await _keyStore.read(
        persistent: data.settings.provider.rememberKey,
      );
      String reply;
      if (apiKey == null || apiKey.trim().isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        reply = _demoReply(character, trimmed);
      } else {
        reply = await _aiClient.streamReply(
          config: data.settings.provider,
          apiKey: apiKey,
          messages: prompt.messages,
          onUpdate: (fullText) {
            if (!mounted || fullText.trim().isEmpty) return;
            final current = state.data;
            var messages = [...current.messages];
            final existingIndex = aiMessageId == null
                ? -1
                : messages.indexWhere((e) => e.id == aiMessageId);
            if (existingIndex >= 0) {
              messages[existingIndex] = messages[existingIndex].copyWith(
                text: fullText,
              );
            } else {
              aiMessageId = _uuid.v4();
              messages.add(
                Message(
                  id: aiMessageId!,
                  threadId: threadId,
                  senderId: character.id,
                  senderName: character.name,
                  text: fullText,
                  createdAt: DateTime.now(),
                  fromAi: true,
                ),
              );
            }
            messages = messages.where((e) => e.isRenderable).toList();
            state = state.copyWith(data: current.copyWith(messages: messages));
          },
        );
      }

      if (!mounted) return;
      final current = state.data;
      final messages = [...current.messages];
      final existingIndex = aiMessageId == null
          ? -1
          : messages.indexWhere((e) => e.id == aiMessageId);
      if (reply.trim().isNotEmpty) {
        if (existingIndex >= 0) {
          messages[existingIndex] = messages[existingIndex].copyWith(
            text: reply.trim(),
          );
        } else {
          aiMessageId = _uuid.v4();
          messages.add(
            Message(
              id: aiMessageId!,
              threadId: threadId,
              senderId: character.id,
              senderName: character.name,
              text: reply.trim(),
              createdAt: DateTime.now(),
              fromAi: true,
            ),
          );
        }
      }
      _appendMessages(
        [],
        threadId,
        baseMessages: messages.where((e) => e.isRenderable).toList(),
        updateMetrics: true,
      );
    } catch (error) {
      if (!mounted) return;
      final fallback = Message(
        id: _uuid.v4(),
        threadId: threadId,
        senderId: character.id,
        senderName: character.name,
        text: '刚才的连接断开了。我还在这里。\\n\\n（模型请求失败：$error）',
        createdAt: DateTime.now(),
        fromAi: true,
      );
      _appendMessages([fallback], threadId);
      state = state.copyWith(error: '模型请求失败：$error');
    } finally {
      if (mounted) state = state.copyWith(clearGenerating: true);
    }
  }

  void _appendMessages(
    List<Message> appended,
    String threadId, {
    List<Message>? baseMessages,
    bool updateMetrics = true,
  }) {
    final current = state.data;
    final now = DateTime.now();
    final messages = [
      ...(baseMessages ?? current.messages),
      ...appended,
    ].where((e) => e.isRenderable).toList();
    final threads = current.threads.map((thread) {
      if (thread.id != threadId) return thread;
      return thread.copyWith(updatedAt: now, unread: 0);
    }).toList();
    final relationships = updateMetrics
        ? current.relationships.map((relationship) {
            final thread = current.threads
                .where((e) => e.id == threadId)
                .firstOrNull;
            if (thread?.relationshipId != relationship.id) {
              return relationship;
            }
            final metrics = Map<String, int>.from(relationship.metrics);
            final affection = metrics['好感'] ?? 0;
            final desire = metrics['心动'] ?? 0;
            metrics['好感'] = (affection + 1).clamp(0, 100);
            metrics['心动'] = (desire + 1).clamp(0, 100);
            return relationship.copyWith(metrics: metrics, updatedAt: now);
          }).toList()
        : current.relationships;
    _commit(
      current.copyWith(
        messages: messages,
        threads: threads,
        relationships: relationships,
      ),
    );
  }

  void upsertMemory(MemoryItem memory) {
    final memories = [...state.data.memories];
    final index = memories.indexWhere((e) => e.id == memory.id);
    if (index >= 0) {
      memories[index] = memory;
    } else {
      memories.add(memory);
    }
    _commit(state.data.copyWith(memories: memories));
  }

  void deleteMemory(String id) {
    _commit(
      state.data.copyWith(
        memories: state.data.memories.where((e) => e.id != id).toList(),
      ),
    );
  }

  void toggleMemoryPinned(String id) {
    _commit(
      state.data.copyWith(
        memories: [
          for (final memory in state.data.memories)
            memory.id == id ? memory.copyWith(pinned: !memory.pinned) : memory,
        ],
      ),
    );
  }

  void updateRelationship(Relationship relationship) {
    _commit(
      state.data.copyWith(
        relationships: [
          for (final item in state.data.relationships)
            item.id == relationship.id ? relationship : item,
        ],
      ),
    );
  }

  void publishMoment(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final data = state.data;
    final moment = Moment(
      id: _uuid.v4(),
      authorId: data.owner.id,
      authorName: data.owner.displayName,
      content: trimmed,
      createdAt: DateTime.now(),
      avatarColor: data.owner.avatarColor,
      likedBy: [for (final character in data.characters) character.name],
      comments: [
        if (data.characters.isNotEmpty)
          MomentComment(
            id: _uuid.v4(),
            authorName: data.characters.first.name,
            content: _momentReply(data.characters.first, trimmed),
            createdAt: DateTime.now(),
            fromAi: true,
          ),
      ],
    );
    _commit(data.copyWith(moments: [moment, ...data.moments]));
  }

  void toggleMomentLike(String momentId, String ownerName) {
    _commit(
      state.data.copyWith(
        moments: [
          for (final moment in state.data.moments)
            moment.id == momentId
                ? moment.copyWith(
                    likedBy: moment.likedBy.contains(ownerName)
                        ? moment.likedBy.where((e) => e != ownerName).toList()
                        : [...moment.likedBy, ownerName],
                  )
                : moment,
        ],
      ),
    );
  }

  void addMomentComment(String momentId, String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final data = state.data;
    _commit(
      data.copyWith(
        moments: [
          for (final moment in data.moments)
            moment.id == momentId
                ? moment.copyWith(
                    comments: [
                      ...moment.comments,
                      MomentComment(
                        id: _uuid.v4(),
                        authorName: data.owner.displayName,
                        content: trimmed,
                        createdAt: DateTime.now(),
                      ),
                    ],
                  )
                : moment,
        ],
      ),
    );
  }

  String exportBackup() => state.data.encode();

  Future<void> importBackup(String raw) async {
    final data = AppData.decode(raw.trim());
    if (data.schemaVersion != 2) {
      throw const FormatException('只支持 Dreamtide V2 备份');
    }
    await _store.save(data);
    _commit(data);
  }

  Future<void> resetDemo() async {
    await _store.clear();
    _commit(buildSeedData());
  }

  String _demoReply(Character character, String input) {
    final lower = input.toLowerCase();
    if (lower.contains('想你') || lower.contains('喜欢')) {
      return '${character.name}看着你，没有立刻回答。过了一会儿，他才低声说：“这句话我听见了。别急着收回去，也别急着要我马上给你一个标准答案。”';
    }
    if (lower.contains('累') || lower.contains('困') || lower.contains('烦')) {
      return '“先别把所有事一起解决。”${character.name}把语速放得很慢，“挑最小的一件告诉我。剩下的，等你缓过来再说。”';
    }
    if (input.contains('？') || input.contains('?')) {
      return '${character.name}沉默了一小会儿，像是在认真斟酌。“我不想随便敷衍你。按我真实的想法，是愿意继续听你说下去。你呢？”';
    }
    return '${character.name}看着你发来的话，指尖在屏幕边缘停了一下。\\n\\n“嗯，我在听。你不用一次说得很完整，想到哪里就说到哪里。”';
  }

  String _momentReply(Character character, String content) {
    if (content.contains('累') || content.contains('忙')) {
      return '看见了。忙完记得休息一会儿，别把今天所有的力气都用完。';
    }
    if (content.contains('想') || content.contains('梦')) {
      return '那等你有空，把这段梦讲给我听。';
    }
    return '看到了。今天也辛苦了。';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _aiClient.close();
    super.dispose();
  }
}

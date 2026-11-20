import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../ai/ai_client.dart';
import '../ai/conversation_summary.dart';
import '../ai/context_assembler.dart';
import '../data/local_store.dart';
import '../data/local_store_factory.dart';
import '../data/provider_key_store.dart';
import '../data/initial_data.dart';
import '../data/attachment_store.dart';
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

final attachmentStoreProvider = Provider<AttachmentStore>(
  (ref) => createAttachmentStore(),
);

final appControllerProvider =
    StateNotifierProvider<AppController, ApplicationState>((ref) {
      return AppController(attachmentStore: ref.watch(attachmentStoreProvider));
    });

final currentPersonaProvider = Provider<UserPersona?>((ref) {
  final data = ref.watch(appControllerProvider).data;
  return data.personaById(data.settings.currentPersonaId);
});

class AppController extends StateNotifier<ApplicationState> {
  AppController({
    LocalDataStore? store,
    ApiKeyStore? keyStore,
    AiClient? aiClient,
    AttachmentStore? attachmentStore,
  }) : _store = store ?? createLocalDataStore(),
       _keyStore = keyStore ?? ProviderKeyStore(),
       _aiClient = aiClient ?? AiClient(),
       _attachmentStore = attachmentStore,
       super(ApplicationState(data: buildEmptyData())) {
    _load();
  }

  final LocalDataStore _store;
  final ApiKeyStore _keyStore;
  final AiClient _aiClient;
  final AttachmentStore? _attachmentStore;
  final ContextAssembler _assembler = const ContextAssembler();
  final Uuid _uuid = const Uuid();
  Timer? _saveTimer;
  bool _hasApiKey = false;
  int _generation = 0;
  int _lifecycleGeneration = 0;
  final Set<String> _summaryInFlight = {};
  final Map<String, DateTime> _summaryRetryAfter = {};
  final Map<String, Completer<void>> _summaryAbortTriggers = {};
  Completer<void>? _activeGenerationAbort;
  String? _activeAssistantMessageId;

  bool get hasApiKey => _hasApiKey;

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  Future<void> _load() async {
    try {
      final loaded = await _store.load();
      final data = loaded ?? buildEmptyData();
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
    if (level.index < state.data.settings.contentCeiling.index &&
        state.generatingThreadId != null) {
      _stopActiveGeneration();
    }
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
    _commit(
      state.data.copyWith(
        personas: personas,
        settings: state.data.settings.currentPersonaId.isEmpty
            ? state.data.settings.copyWith(currentPersonaId: persona.id)
            : state.data.settings,
      ),
    );
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
    if (data.personaById(data.settings.currentPersonaId) == null) {
      throw StateError('请先创建并选择梦设');
    }
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
        messages: [...data.messages, if (greeting.isRenderable) greeting],
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

  Future<List<ProviderModel>> fetchProviderModels({
    required ProviderConfig config,
    String? apiKey,
  }) async {
    final key = apiKey?.trim().isNotEmpty == true
        ? apiKey!.trim()
        : await _keyStore.read(
            persistent: state.data.settings.provider.rememberKey,
          );
    return _aiClient.fetchModels(config: config, apiKey: key ?? '');
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
    await flush();
  }

  Future<void> clearProviderKey() async {
    await _keyStore.clear();
    _hasApiKey = false;
    state = state.copyWith(hasApiKey: false);
  }

  Future<void> sendMessage(
    String threadId,
    String text, {
    MessageKind kind = MessageKind.text,
    String? localPath,
    void Function()? onAccepted,
  }) async {
    final trimmed = text.trim();
    final isImage = kind == MessageKind.image && localPath?.isNotEmpty == true;
    if (trimmed.isEmpty && !isImage) return;
    final pendingSummary = _summaryAbortTriggers[threadId];
    if (pendingSummary != null && !pendingSummary.isCompleted) {
      pendingSummary.complete();
    }
    if (state.generatingThreadId != null || _activeGenerationAbort != null) {
      _stopActiveGeneration();
    }
    final epoch = ++_generation;
    final abort = Completer<void>();
    _activeGenerationAbort = abort;
    state = state.copyWith(generatingThreadId: threadId, clearError: true);
    var data = state.data;
    final thread = data.threads.where((e) => e.id == threadId).firstOrNull;
    if (thread == null) {
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      state = state.copyWith(clearGenerating: true);
      return;
    }
    final relationship = data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    if (relationship == null || character == null) {
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      state = state.copyWith(clearGenerating: true);
      return;
    }

    if (!isImage &&
        trimmed.toLowerCase() == relationship.consent.safeWord.toLowerCase()) {
      final stoppedRelationship = relationship.copyWith(
        consent: relationship.consent.copyWith(paused: true),
      );
      final userMessage = Message(
        id: _uuid.v4(),
        threadId: threadId,
        senderId: data.owner.id,
        senderName: data.owner.displayName,
        text: trimmed,
        createdAt: DateTime.now(),
      );
      final safetyMessage = Message(
        id: _uuid.v4(),
        threadId: threadId,
        senderId: character.id,
        senderName: character.name,
        text: '我在。已经停下来了。先不继续剧情，告诉我你现在需要安静、陪伴，还是结束这次场景。',
        createdAt: DateTime.now(),
        fromAi: true,
      );
      _appendMessages(
        [userMessage, safetyMessage],
        threadId,
        relationshipUpdate: stoppedRelationship,
      );
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      state = state.copyWith(clearGenerating: true);
      onAccepted?.call();
      return;
    }

    final apiKey = await _keyStore.read(
      persistent: data.settings.provider.rememberKey,
    );
    if (!mounted || epoch != _generation || abort.isCompleted) return;
    if (apiKey == null ||
        apiKey.trim().isEmpty ||
        data.settings.provider.model.trim().isEmpty) {
      state = state.copyWith(error: '请先配置 API Key、拉取并选择模型');
      state = state.copyWith(clearGenerating: true);
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      return;
    }

    data = state.data;
    final activeThread = data.threads
        .where((item) => item.id == threadId)
        .firstOrNull;
    final activeRelationship = activeThread == null
        ? null
        : data.relationshipForThread(activeThread);
    final activeCharacter = activeRelationship == null
        ? null
        : data.characterForRelationship(activeRelationship);
    if (activeThread == null ||
        activeRelationship == null ||
        activeCharacter == null) {
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      state = state.copyWith(clearGenerating: true);
      return;
    }

    final promptInput = isImage
        ? (trimmed.isEmpty ? '（用户发送了一张图片）' : '（用户发送了一张图片）$trimmed')
        : trimmed;
    final prompt = _assembler.assemble(
      data: data,
      thread: activeThread,
      userInput: promptInput,
    );
    final acceptedAt = DateTime.now();
    final userMessage = Message(
      id: _uuid.v4(),
      threadId: threadId,
      senderId: data.owner.id,
      senderName: data.owner.displayName,
      text: trimmed,
      createdAt: acceptedAt,
      kind: kind,
      localPath: localPath,
    );
    final relationshipAfterInput = activeRelationship.copyWith(
      replyEnergy: prompt.replyPlan.energy,
      lastInteractionAt: acceptedAt,
    );
    _appendMessages(
      [userMessage],
      threadId,
      relationshipUpdate: relationshipAfterInput,
    );
    onAccepted?.call();

    if (!prompt.replyPlan.shouldReply) {
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      state = state.copyWith(clearGenerating: true);
      return;
    }

    final generation = epoch;
    String? aiMessageId;
    var shouldSummarize = false;
    try {
      final reply = await _aiClient.streamReply(
        config: data.settings.provider,
        apiKey: apiKey,
        messages: prompt.messages,
        abortTrigger: abort.future,
        onUpdate: (fullText) {
          if (!mounted ||
              generation != _generation ||
              fullText.trim().isEmpty) {
            return;
          }
          final current = state.data;
          var messages = [...current.messages];
          final existingIndex = aiMessageId == null
              ? -1
              : messages.indexWhere((e) => e.id == aiMessageId);
          final visibleText = prompt.replyPlan.prepareText(fullText);
          if (visibleText.isEmpty) return;
          if (existingIndex >= 0) {
            messages[existingIndex] = messages[existingIndex].copyWith(
              text: visibleText,
            );
          } else {
            aiMessageId = _uuid.v4();
            messages.add(
              Message(
                id: aiMessageId!,
                threadId: threadId,
                senderId: activeCharacter.id,
                senderName: activeCharacter.name,
                text: visibleText,
                createdAt: DateTime.now(),
                fromAi: true,
              ),
            );
            _activeAssistantMessageId = aiMessageId;
          }
          messages = messages.where((e) => e.isRenderable).toList();
          state = state.copyWith(data: current.copyWith(messages: messages));
        },
      );

      if (!mounted || generation != _generation) return;
      final naturalReply = prompt.replyPlan.prepareText(reply);
      final current = state.data;
      final messages = [...current.messages];
      final existingIndex = aiMessageId == null
          ? -1
          : messages.indexWhere((e) => e.id == aiMessageId);
      if (reply.trim().isNotEmpty) {
        if (existingIndex >= 0) {
          messages[existingIndex] = messages[existingIndex].copyWith(
            text: naturalReply,
          );
        } else {
          aiMessageId = _uuid.v4();
          messages.add(
            Message(
              id: aiMessageId!,
              threadId: threadId,
              senderId: activeCharacter.id,
              senderName: activeCharacter.name,
              text: naturalReply,
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
      );
      shouldSummarize = true;
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(error: '模型请求失败：$error');
    } finally {
      if (mounted && generation == _generation) {
        state = state.copyWith(clearGenerating: true);
      }
      if (identical(_activeGenerationAbort, abort)) {
        _activeGenerationAbort = null;
      }
      if (aiMessageId != null && _activeAssistantMessageId == aiMessageId) {
        _activeAssistantMessageId = null;
      }
    }
    if (shouldSummarize && mounted) {
      unawaited(_refreshConversationMemo(threadId, _lifecycleGeneration));
    }
  }

  /// Replays the latest user turn. This is used after a failed request where no
  /// assistant message was persisted, so the user does not have to retype it.
  Future<void> retryLastTurn(String threadId, {void Function()? onAccepted}) =>
      _replayLastTurn(
        threadId,
        requireAssistantReply: false,
        onAccepted: onAccepted,
      );

  /// Replaces the latest assistant response while keeping the same user turn.
  Future<void> regenerateLastReply(
    String threadId, {
    void Function()? onAccepted,
  }) => _replayLastTurn(
    threadId,
    requireAssistantReply: true,
    onAccepted: onAccepted,
  );

  Future<void> _replayLastTurn(
    String threadId, {
    required bool requireAssistantReply,
    void Function()? onAccepted,
  }) async {
    if (state.generatingThreadId != null || _activeGenerationAbort != null) {
      return;
    }
    final data = state.data;
    final thread = data.threads
        .where((item) => item.id == threadId)
        .firstOrNull;
    if (thread == null) return;
    final history =
        data.messages
            .where(
              (message) => message.threadId == threadId && message.isRenderable,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final userIndex = history.lastIndexWhere(
      (message) => !message.fromAi && message.kind != MessageKind.system,
    );
    if (userIndex < 0) {
      state = state.copyWith(error: '没有可以重试的用户消息');
      return;
    }
    final user = history[userIndex];
    final hasAssistantReply = history
        .skip(userIndex + 1)
        .any((message) => message.fromAi);
    if (requireAssistantReply && !hasAssistantReply) {
      state = state.copyWith(error: '上一条还没有生成可重新生成的回复');
      return;
    }

    final apiKey = await _keyStore.read(
      persistent: data.settings.provider.rememberKey,
    );
    if (!mounted) return;
    if (apiKey == null ||
        apiKey.trim().isEmpty ||
        data.settings.provider.model.trim().isEmpty) {
      state = state.copyWith(error: '请先配置 API Key、拉取并选择模型');
      return;
    }

    final removedIds = {
      for (var index = userIndex; index < history.length; index++)
        history[index].id,
    };
    final remaining = data.messages
        .where((message) => !removedIds.contains(message.id))
        .toList();
    final remainingInThread =
        remaining.where((message) => message.threadId == threadId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final cursorRemoved =
        thread.summarizedThroughMessageId != null &&
        removedIds.contains(thread.summarizedThroughMessageId);
    final replacementCursor = remainingInThread.lastOrNull?.id;

    _commit(
      data.copyWith(
        messages: remaining,
        threads: [
          for (final item in data.threads)
            if (item.id == threadId && cursorRemoved)
              item.copyWith(
                summarizedThroughMessageId: replacementCursor,
                clearSummarizedThroughMessageId: replacementCursor == null,
              )
            else
              item,
        ],
      ),
    );
    await sendMessage(
      threadId,
      user.text,
      kind: user.kind,
      localPath: user.localPath,
      onAccepted: onAccepted,
    );
  }

  /// Stop the active stream but keep any text already produced as a partial
  /// assistant turn, so the next message has the real conversational context.
  Future<void> interruptGeneration() async {
    if (state.generatingThreadId == null && _activeGenerationAbort == null) {
      return;
    }
    _stopActiveGeneration();
    await flush();
  }

  void _stopActiveGeneration() {
    ++_generation;
    final abort = _activeGenerationAbort;
    _activeGenerationAbort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
    final messageId = _activeAssistantMessageId;
    _activeAssistantMessageId = null;
    var data = state.data;
    if (messageId != null) {
      data = data.copyWith(
        messages: [
          for (final message in data.messages)
            if (message.id == messageId)
              message.copyWith(interrupted: true)
            else
              message,
        ],
      );
    }
    state = state.copyWith(clearGenerating: true);
    _commit(data);
  }

  /// Edits the narrative recap from the relationship memory screen. Clearing
  /// Clearing a memo advances its cursor to the latest completed message, so
  /// a user deletion is not silently undone by replaying the same old turns.
  void setThreadContextMemo(String threadId, String value) {
    final memo = value.trim();
    _summaryRetryAfter.remove(threadId);
    final latestMessageId = state.data.messages
        .where(
          (message) =>
              message.threadId == threadId &&
              message.kind != MessageKind.system &&
              !message.interrupted &&
              message.isRenderable,
        )
        .lastOrNull
        ?.id;
    _commit(
      state.data.copyWith(
        threads: [
          for (final thread in state.data.threads)
            if (thread.id == threadId)
              thread.copyWith(
                contextMemo: memo,
                contextMemoUpdatedAt: memo.isEmpty ? null : DateTime.now(),
                clearContextMemoUpdatedAt: memo.isEmpty,
                summarizedThroughMessageId: memo.isEmpty
                    ? latestMessageId
                    : null,
                clearSummarizedThroughMessageId:
                    memo.isEmpty && latestMessageId == null,
              )
            else
              thread,
        ],
      ),
    );
  }

  Future<void> _refreshConversationMemo(
    String threadId,
    int lifecycleGeneration,
  ) async {
    if (!mounted ||
        lifecycleGeneration != _lifecycleGeneration ||
        !_summaryInFlight.add(threadId)) {
      return;
    }
    final abort = Completer<void>();
    _summaryAbortTriggers[threadId] = abort;
    try {
      final data = state.data;
      final thread = data.threads
          .where((item) => item.id == threadId)
          .firstOrNull;
      if (thread == null) return;
      final retryAfter = _summaryRetryAfter[threadId];
      if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return;
      final window = ConversationSummaryWindow.create(
        thread: thread,
        source: data.messages,
      );
      if (window == null) return;
      final config = data.settings.provider;
      final apiKey = await _keyStore.read(persistent: config.rememberKey);
      if (!mounted || lifecycleGeneration != _lifecycleGeneration) return;
      if (apiKey == null || apiKey.trim().isEmpty) return;

      final memoryUpdate = await _aiClient.summarizeConversation(
        config: config,
        apiKey: apiKey,
        previousSummary: thread.contextMemo,
        previousFacts: [
          for (final item in data.memories)
            if (item.autoGenerated &&
                item.type != MemoryType.boundary &&
                item.sourceThreadId == thread.id)
              ConversationMemoryFact(
                type: item.type,
                title: item.title,
                content: item.content,
                sourceMessageId: item.sourceMessageId ?? '',
              ),
        ],
        conversationExcerpt: window.toTranscript(),
        abortTrigger: abort.future,
      );
      if (!mounted || lifecycleGeneration != _lifecycleGeneration) return;
      final current = state.data;
      final currentThread = current.threads
          .where((item) => item.id == threadId)
          .firstOrNull;
      // Do not overwrite a manual edit or another summary that completed while
      // this provider request was running.
      if (currentThread == null ||
          current.settings.provider.kind != config.kind ||
          current.settings.provider.baseUrl != config.baseUrl ||
          current.settings.provider.model != config.model ||
          currentThread.contextMemo != thread.contextMemo ||
          currentThread.summarizedThroughMessageId !=
              thread.summarizedThroughMessageId) {
        return;
      }
      final nextMemories = _mergeConversationFacts(
        existing: current.memories,
        thread: currentThread,
        relationshipId: currentThread.relationshipId,
        sourceMessages: data.messages,
        facts: memoryUpdate.facts,
        suppressedKeys: currentThread.suppressedMemoryKeys.toSet(),
      );
      final updated = current.copyWith(
        threads: [
          for (final item in current.threads)
            if (item.id == threadId)
              item.copyWith(
                contextMemo: memoryUpdate.summary,
                contextMemoUpdatedAt: DateTime.now(),
                summarizedThroughMessageId: window.lastMessageId,
              )
            else
              item,
        ],
        memories: nextMemories,
      );
      _commit(updated);
      await flush();
      _summaryRetryAfter.remove(threadId);
    } catch (_) {
      // Memory is auxiliary: never surface a second-request failure as a chat
      // error or replace the last known-good memo.
      if (!abort.isCompleted) {
        _summaryRetryAfter[threadId] = DateTime.now().add(
          const Duration(minutes: 5),
        );
      }
    } finally {
      _summaryInFlight.remove(threadId);
      if (identical(_summaryAbortTriggers[threadId], abort)) {
        _summaryAbortTriggers.remove(threadId);
      }
    }

    // Limit background work to one quiet request per completed visible turn.
    // Older backlogs are summarized in bounded batches on later turns.
  }

  List<MemoryItem> _mergeConversationFacts({
    required List<MemoryItem> existing,
    required ChatThread thread,
    required String relationshipId,
    required List<Message> sourceMessages,
    required List<ConversationMemoryFact> facts,
    required Set<String> suppressedKeys,
  }) {
    final generated = existing
        .where((item) => item.autoGenerated && item.sourceThreadId == thread.id)
        .toList();
    final next = [...existing];
    final seen = <String>{};
    for (final fact in facts) {
      final key = '${fact.type.name}:${fact.title.trim().toLowerCase()}';
      if (!seen.add(key) || suppressedKeys.contains(key)) continue;
      final source = sourceMessages
          .where(
            (message) =>
                message.id == fact.sourceMessageId &&
                message.threadId == thread.id,
          )
          .firstOrNull;
      if (source == null ||
          fact.type == MemoryType.boundary ||
          (fact.type == MemoryType.userFact && source.fromAi)) {
        continue;
      }
      if (existing.any(
        (item) =>
            !item.autoGenerated &&
            item.relationshipId == relationshipId &&
            item.type == fact.type &&
            item.title.trim().toLowerCase() == fact.title.trim().toLowerCase(),
      )) {
        continue;
      }
      final prior = generated
          .where(
            (item) =>
                item.type == fact.type &&
                item.title.trim().toLowerCase() ==
                    fact.title.trim().toLowerCase(),
          )
          .firstOrNull;
      if (prior != null) {
        final index = next.indexWhere((item) => item.id == prior.id);
        next[index] = prior.copyWith(
          type: fact.type,
          title: fact.title,
          content: fact.content,
          autoGenerated: true,
          sourceMessageId: fact.sourceMessageId,
        );
      } else if (next
              .where(
                (item) =>
                    item.autoGenerated && item.sourceThreadId == thread.id,
              )
              .length <
          48) {
        next.add(
          MemoryItem(
            id: prior?.id ?? _uuid.v4(),
            relationshipId: relationshipId,
            type: fact.type,
            title: fact.title,
            content: fact.content,
            createdAt: prior?.createdAt ?? DateTime.now(),
            sourceThreadId: thread.id,
            sourceMessageId: fact.sourceMessageId,
            pinned: prior?.pinned ?? false,
            autoGenerated: true,
          ),
        );
      }
    }
    return next;
  }

  void _appendMessages(
    List<Message> appended,
    String threadId, {
    List<Message>? baseMessages,
    Relationship? relationshipUpdate,
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
    final relationships = relationshipUpdate == null
        ? current.relationships
        : [
            for (final item in current.relationships)
              item.id == relationshipUpdate.id
                  ? relationshipUpdate.copyWith(updatedAt: now)
                  : item,
          ];
    _commit(
      current.copyWith(
        messages: messages,
        threads: threads,
        relationships: relationships,
      ),
    );
  }

  void upsertMemory(MemoryItem memory) {
    final prior = state.data.memories
        .where((item) => item.id == memory.id)
        .firstOrNull;
    final memories = [...state.data.memories];
    final index = memories.indexWhere((e) => e.id == memory.id);
    if (index >= 0) {
      memories[index] = memory;
    } else {
      memories.add(memory);
    }
    final key = '${memory.type.name}:${memory.title.trim().toLowerCase()}';
    final suppressedKey = prior == null
        ? key
        : '${prior.type.name}:${prior.title.trim().toLowerCase()}';
    final suppressAutoFact =
        prior?.autoGenerated == true && !memory.autoGenerated;
    _commit(
      state.data.copyWith(
        memories: memories,
        threads: memory.sourceThreadId == null
            ? state.data.threads
            : [
                for (final thread in state.data.threads)
                  if (thread.id == memory.sourceThreadId)
                    thread.copyWith(
                      suppressedMemoryKeys: suppressAutoFact
                          ? {
                              ...thread.suppressedMemoryKeys,
                              suppressedKey,
                            }.toList()
                          : thread.suppressedMemoryKeys
                                .where((item) => item != key)
                                .toList(),
                    )
                  else
                    thread,
              ],
      ),
    );
  }

  void deleteMemory(String id) {
    final memory = state.data.memories
        .where((item) => item.id == id)
        .firstOrNull;
    final key = memory == null
        ? null
        : '${memory.type.name}:${memory.title.trim().toLowerCase()}';
    _commit(
      state.data.copyWith(
        memories: state.data.memories.where((e) => e.id != id).toList(),
        threads:
            memory == null ||
                !memory.autoGenerated ||
                memory.sourceThreadId == null ||
                key == null
            ? state.data.threads
            : [
                for (final thread in state.data.threads)
                  if (thread.id == memory.sourceThreadId)
                    thread.copyWith(
                      suppressedMemoryKeys: {
                        ...thread.suppressedMemoryKeys,
                        key,
                      }.toList(),
                    )
                  else
                    thread,
              ],
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
    final previous = state.data.relationships
        .where((item) => item.id == relationship.id)
        .firstOrNull;
    if (relationship.consent.paused &&
        previous?.consent.paused != true &&
        state.generatingThreadId != null) {
      _stopActiveGeneration();
    }
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
    _cancelActiveGeneration();
    _cancelPendingSummaries();
    state = state.copyWith(clearGenerating: true);
    ++_generation;
    ++_lifecycleGeneration;
    _summaryRetryAfter.clear();
    await _store.save(data);
    _commit(data);
    state = state.copyWith(clearGenerating: true);
  }

  Future<void> resetData() async {
    _cancelActiveGeneration();
    _cancelPendingSummaries();
    state = state.copyWith(clearGenerating: true);
    ++_generation;
    ++_lifecycleGeneration;
    _summaryRetryAfter.clear();
    _saveTimer?.cancel();
    await _attachmentStore?.clear();
    await _keyStore.clear();
    await _store.clear();
    _hasApiKey = false;
    _commit(buildEmptyData());
    state = state.copyWith(hasApiKey: false, clearGenerating: true);
    await flush();
  }

  @override
  void dispose() {
    _cancelActiveGeneration();
    _cancelPendingSummaries();
    ++_lifecycleGeneration;
    _saveTimer?.cancel();
    _aiClient.close();
    super.dispose();
  }

  void _cancelActiveGeneration() {
    final abort = _activeGenerationAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _activeGenerationAbort = null;
  }

  void _cancelPendingSummaries() {
    for (final abort in _summaryAbortTriggers.values) {
      if (!abort.isCompleted) abort.complete();
    }
    _summaryAbortTriggers.clear();
  }
}

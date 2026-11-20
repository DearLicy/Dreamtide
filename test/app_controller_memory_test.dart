import 'dart:async';
import 'dart:convert';

import 'package:dreamtide/ai/ai_client.dart';
import 'package:dreamtide/ai/context_assembler.dart';
import 'package:dreamtide/application/app_controller.dart';
import 'package:dreamtide/data/local_store_base.dart';
import 'package:dreamtide/data/provider_key_store.dart';
import 'package:dreamtide/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/sample_data.dart';

class _MemoryStore implements LocalDataStore {
  _MemoryStore(this.value);

  AppData? value;
  final savedMemo = Completer<String>();

  @override
  Future<AppData?> load() async => value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<void> save(AppData data) async {
    value = data;
    final memo = data.threads
        .where((thread) => thread.id == 'thread_gu')
        .firstOrNull
        ?.contextMemo;
    if (memo != null && memo.isNotEmpty && !savedMemo.isCompleted) {
      savedMemo.complete(memo);
    }
  }
}

class _MemoryKeyStore implements ApiKeyStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read({required bool persistent}) async => 'test-key';

  @override
  Future<void> write(String value, {required bool persistent}) async {}
}

void main() {
  test(
    'quiet summary is persisted after reply and injected into the next turn',
    () async {
      final initial = buildSeedData();
      final config = const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://memory.test/v1',
        model: 'memory-model',
      );
      final thread = initial.threads.firstWhere(
        (item) => item.id == 'thread_gu',
      );
      final start = DateTime.now().subtract(const Duration(days: 1));
      final transcript = [
        for (var index = 0; index < 16; index++)
          Message(
            id: 'history-$index',
            threadId: thread.id,
            senderId: index.isEven ? initial.owner.id : 'char_gu',
            senderName: index.isEven ? initial.owner.displayName : '顾言',
            text: '历史对话第 $index 条，约定周末去看海。',
            createdAt: start.add(Duration(minutes: index)),
            fromAi: index.isOdd,
          ),
      ];
      final data = initial.copyWith(
        settings: initial.settings.copyWith(provider: config),
        messages: transcript,
      );
      final store = _MemoryStore(data);
      final summaryRequest = Completer<void>();
      final summaryResponse = Completer<http.Response>();
      final mainRequestBodies = <Map<String, dynamic>>[];
      var mainRequests = 0;
      final client = AiClient(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['stream'] == true) {
            mainRequests++;
            mainRequestBodies.add(body);
            return http.Response(
              'data: {"choices":[{"delta":{"content":"我记得，我们说好周末去看海。"}}]}\n\ndata: [DONE]\n\n',
              200,
              headers: {'content-type': 'text/event-stream; charset=utf-8'},
            );
          }
          expect(body['messages'].last['content'], contains('历史对话第'));
          summaryRequest.complete();
          return summaryResponse.future;
        }),
      );
      final controller = AppController(
        store: store,
        keyStore: _MemoryKeyStore(),
        aiClient: client,
      );
      addTearDown(controller.dispose);

      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(controller.state.loading, isFalse);

      await controller.sendMessage(thread.id, '你还记得我们周末的约定吗？');
      await summaryRequest.future.timeout(const Duration(seconds: 2));
      expect(controller.state.generatingThreadId, isNull);
      expect(
        controller.state.data.threads
            .firstWhere((item) => item.id == thread.id)
            .contextMemo,
        isEmpty,
      );
      summaryResponse.complete(
        http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': '用户与顾言约好周末一起去看海。顾言记得这是双方确认的共同计划。',
                      'facts': [
                        {
                          'type': 'promise',
                          'title': '周末看海',
                          'content': '用户与顾言约好周末一起去看海。',
                          'source_message_id': 'history-8',
                        },
                      ],
                    }),
                  },
                },
              ],
            }),
          ),
          200,
        ),
      );
      final persistedMemo = await store.savedMemo.future.timeout(
        const Duration(seconds: 2),
      );
      expect(persistedMemo, contains('周末一起去看海'));
      expect(
        controller.state.data.memories.any(
          (memory) => memory.autoGenerated && memory.title == '周末看海',
        ),
        isTrue,
      );
      expect(
        controller.state.data.threads
            .firstWhere((item) => item.id == thread.id)
            .summarizedThroughMessageId,
        'history-9',
      );
      expect(controller.state.error, isNull);

      await controller.sendMessage(thread.id, '下周我们还去吗？');
      expect(mainRequests, 2);
      final secondSystem =
          (mainRequestBodies.last['messages'] as List).firstWhere(
                (item) => item['role'] == 'system',
              )['content']
              as String;
      expect(secondSystem, contains('用户与顾言约好周末一起去看海'));

      final latestId = controller.state.data.messages
          .where((message) => message.threadId == thread.id)
          .last
          .id;
      controller.setThreadContextMemo(thread.id, '');
      final clearedThread = controller.state.data.threads.firstWhere(
        (item) => item.id == thread.id,
      );
      expect(clearedThread.contextMemo, isEmpty);
      expect(clearedThread.summarizedThroughMessageId, latestId);
    },
  );

  test(
    'a new message aborts the current stream and retains its partial turn',
    () async {
      final initial = buildSeedData();
      final config = const ProviderConfig(
        kind: ProviderKind.openaiCompatible,
        baseUrl: 'https://memory.test/v1',
        model: 'memory-model',
      );
      final data = initial.copyWith(
        settings: initial.settings.copyWith(provider: config),
      );
      final ai = _InterruptibleAi();
      final controller = AppController(
        store: _MemoryStore(data),
        keyStore: _MemoryKeyStore(),
        aiClient: ai,
      );
      addTearDown(controller.dispose);
      for (
        var attempt = 0;
        attempt < 20 && controller.state.loading;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final threadId = data.threads.first.id;
      final firstTurn = controller.sendMessage(threadId, '接着说');
      await ai.firstStarted.future.timeout(const Duration(seconds: 2));

      await controller.sendMessage(threadId, '换个话题');
      await firstTurn;

      final partial = controller.state.data.messages.singleWhere(
        (message) => message.text == '我本来想说……',
      );
      expect(partial.interrupted, isTrue);
      expect(controller.state.generatingThreadId, isNull);
      expect(
        ai.requests.last.any(
          (message) =>
              message.role == 'assistant' &&
              message.content.contains('上一条回复被用户打断') &&
              message.content.contains('我本来想说……'),
        ),
        isTrue,
      );
    },
  );
}

class _InterruptibleAi extends AiClient {
  final firstStarted = Completer<void>();
  final requests = <List<PromptMessage>>[];

  @override
  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String) onUpdate,
    int maxOutputTokens = 420,
    Future<void>? abortTrigger,
  }) async {
    requests.add(messages);
    if (requests.length == 1) {
      onUpdate('我本来想说……');
      firstStarted.complete();
      await abortTrigger;
      throw http.RequestAbortedException(Uri.parse('https://memory.test'));
    }
    return '行，那改天吧。';
  }
}

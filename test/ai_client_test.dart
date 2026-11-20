import 'dart:convert';
import 'package:dreamtide/ai/ai_client.dart';
import 'package:dreamtide/ai/context_assembler.dart';
import 'package:dreamtide/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'official model catalog uses authenticated /models and actual unique ids',
    () async {
      final ai = AiClient(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://api.deepseek.com/models');
          expect(request.headers['Authorization'], 'Bearer test-key');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'actual-model', 'name': 'Actual'},
                {'id': 'actual-model'},
                {'id': 'other'},
                {'id': ''},
              ],
            }),
            200,
          );
        }),
      );
      final models = await ai.fetchModels(
        config: const ProviderConfig(),
        apiKey: 'test-key',
      );
      expect(models.map((e) => e.id), ['actual-model', 'other']);
      expect(models.first.name, 'Actual');
      ai.close();
    },
  );
  test(
    'catalog errors never expose upstream response or credentials',
    () async {
      final ai = AiClient(
        client: MockClient(
          (_) async => http.Response('test-key upstream private details', 401),
        ),
      );
      await expectLater(
        ai.fetchModels(config: const ProviderConfig(), apiKey: 'test-key'),
        throwsA(
          isA<AiClientException>().having(
            (e) => e.message,
            'safe error',
            '密钥无效或没有访问模型的权限',
          ),
        ),
      );
      ai.close();
    },
  );
  test('empty or invalid catalogs never invent selectable models', () async {
    for (final body in [
      '{"data":[]}',
      '{"models":[]}',
      '{"data":[{"id":""}]}',
    ]) {
      final ai = AiClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        ai.fetchModels(config: const ProviderConfig(), apiKey: 'test-key'),
        throwsA(isA<AiClientException>()),
      );
      ai.close();
    }
  });
  test('DeepSeek Anthropic compatibility streams only text deltas', () async {
    final ai = AiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/anthropic/v1/messages');
        expect(jsonDecode(request.body)['model'], 'actual-model');
        return http.Response(
          'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"（回头）"}}\n\ndata: {"type":"ping"}\n\ndata: {"type":"content_block_delta","delta":{"text":"你好"}}\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    final updates = <String>[];
    final text = await ai.streamReply(
      config: const ProviderConfig(model: 'actual-model'),
      apiKey: 'test-key',
      messages: const [PromptMessage('user', 'hello')],
      onUpdate: updates.add,
    );
    expect(text, '（回头）你好');
    expect(updates, ['（回头）', '（回头）你好']);
    ai.close();
  });
}

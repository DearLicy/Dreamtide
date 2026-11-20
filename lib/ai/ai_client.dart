import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'context_assembler.dart';

class AiClientException implements Exception {
  const AiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiClient {
  AiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Model ids and labels come only from the provider's authenticated catalog.
  Future<List<ProviderModel>> fetchModels({
    required ProviderConfig config,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) throw const AiClientException('请先填写 API Key');
    final base = _baseUri(config.baseUrl);
    final official = base.host.toLowerCase() == 'api.deepseek.com';
    final uri = official
        ? base.replace(path: '/models')
        : _endpoint(config.baseUrl, '/models');
    final response = await _client
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Accept': 'application/json',
            if (!official && config.kind == ProviderKind.anthropic) ...{
              'x-api-key': apiKey.trim(),
              'anthropic-version': '2023-06-01',
            },
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw AiClientException(switch (response.statusCode) {
        401 || 403 => '密钥无效或没有访问模型的权限',
        429 => '请求过于频繁，请稍后重试',
        _ => '模型列表拉取失败（HTTP ${response.statusCode}）',
      });
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map || body['data'] is! List) {
      throw const AiClientException('供应商返回的模型列表格式不正确');
    }
    final seen = <String>{};
    final models = <ProviderModel>[];
    for (final item in body['data'] as List) {
      if (item is! Map || item['id'] is! String) continue;
      final id = (item['id'] as String).trim();
      if (id.isEmpty || !seen.add(id)) continue;
      models.add(
        ProviderModel(
          id: id,
          name: item['name'] is String ? item['name'] as String : id,
        ),
      );
    }
    if (models.isEmpty) throw const AiClientException('供应商没有返回可用模型');
    return models;
  }

  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String fullText) onUpdate,
  }) async {
    if (config.model.trim().isEmpty) throw const AiClientException('请先拉取并选择模型');
    if (apiKey.trim().isEmpty) {
      throw const AiClientException('尚未配置 API Key');
    }
    switch (config.kind) {
      case ProviderKind.openaiCompatible:
        return _streamOpenAi(
          config: config,
          apiKey: apiKey,
          messages: messages,
          onUpdate: onUpdate,
        );
      case ProviderKind.anthropic:
        return _streamAnthropic(
          config: config,
          apiKey: apiKey,
          messages: messages,
          onUpdate: onUpdate,
        );
    }
  }

  Future<String> _streamOpenAi({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String fullText) onUpdate,
  }) async {
    final uri = _endpoint(config.baseUrl, '/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': config.model,
        'stream': true,
        'temperature': 0.85,
        'messages': [
          for (final message in messages)
            {'role': message.role, 'content': message.content},
        ],
      });
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw AiClientException(
        '模型请求失败（HTTP ${response.statusCode}），请检查密钥、模型和供应商地址',
      );
    }

    final buffer = StringBuffer();
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        final choices = map['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final first = Map<String, dynamic>.from(choices.first as Map);
        final delta = first['delta'];
        if (delta is Map) {
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            buffer.write(content);
            onUpdate(buffer.toString());
          }
        }
      } catch (_) {
        // Providers occasionally send keep-alive or vendor-specific frames.
      }
    }
    if (buffer.toString().trim().isEmpty) {
      throw const AiClientException('模型返回了空内容');
    }
    return buffer.toString().trim();
  }

  Future<String> _streamAnthropic({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String fullText) onUpdate,
  }) async {
    final base = _baseUri(config.baseUrl);
    final uri = base.host.toLowerCase() == 'api.deepseek.com'
        ? base.replace(path: '/anthropic/v1/messages')
        : _endpoint(config.baseUrl, '/messages');
    final system = messages
        .where((e) => e.role == 'system')
        .map((e) => e.content)
        .join('\n\n');
    final chat = messages.where((e) => e.role != 'system').toList();
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': config.model,
        'max_tokens': 2048,
        'stream': true,
        'system': system,
        'messages': [
          for (final message in chat)
            {'role': message.role, 'content': message.content},
        ],
      });
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw AiClientException(
        '模型请求失败（HTTP ${response.statusCode}），请检查密钥、模型和供应商地址',
      );
    }

    final buffer = StringBuffer();
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        if (map['type'] == 'content_block_delta') {
          final delta = map['delta'];
          if (delta is Map && delta['text'] is String) {
            buffer.write(delta['text'] as String);
            onUpdate(buffer.toString());
          }
        }
      } catch (_) {}
    }
    if (buffer.toString().trim().isEmpty) {
      throw const AiClientException('模型返回了空内容');
    }
    return buffer.toString().trim();
  }

  Uri _endpoint(String baseUrl, String suffix) {
    final uri = _baseUri(baseUrl);
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    path = path.replaceFirst(
      RegExp(r'/(chat/completions|messages|models)$'),
      '',
    );
    if (!path.endsWith('/v1')) path = '$path/v1';
    return uri.replace(path: '$path$suffix');
  }

  Uri _baseUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const AiClientException('请填写不含查询参数的有效 HTTP(S) 供应商地址');
    }
    return uri;
  }

  void close() => _client.close();
}

class ProviderModel {
  const ProviderModel({required this.id, required this.name});
  final String id;
  final String name;
}

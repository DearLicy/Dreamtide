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

  Future<String> streamReply({
    required ProviderConfig config,
    required String apiKey,
    required List<PromptMessage> messages,
    required void Function(String fullText) onUpdate,
  }) async {
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
      final body = await response.stream.bytesToString();
      throw AiClientException('模型请求失败（${response.statusCode}）：${_short(body)}');
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
    final uri = _endpoint(config.baseUrl, '/messages');
    final system = messages
        .where((e) => e.role == 'system')
        .map((e) => e.content)
        .join('\n\n');
    final chat = messages.where((e) => e.role != 'system').toList();
    final request = http.Request('POST', uri)
      ..headers.addAll({
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
      final body = await response.stream.bytesToString();
      throw AiClientException('模型请求失败（${response.statusCode}）：${_short(body)}');
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
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/chat/completions') || base.endsWith('/messages')) {
      return Uri.parse(base);
    }
    if (base.endsWith('/v1')) return Uri.parse('$base$suffix');
    return Uri.parse('$base/v1$suffix');
  }

  String _short(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 240 ? compact : '${compact.substring(0, 240)}…';
  }

  void close() => _client.close();
}

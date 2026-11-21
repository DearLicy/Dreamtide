import 'dart:convert';

import '../domain/models.dart';

class ConversationMemoryFact {
  const ConversationMemoryFact({
    required this.type,
    required this.title,
    required this.content,
    required this.sourceMessageId,
  });

  final MemoryType type;
  final String title;
  final String content;
  final String sourceMessageId;
}

class ConversationMemoryUpdate {
  const ConversationMemoryUpdate({required this.summary, required this.facts});

  final String summary;
  final List<ConversationMemoryFact> facts;
}

/// Selects an older, already completed segment for an incremental quiet summary.
/// Recent messages stay in the ordinary prompt while the summary covers older
/// turns. The original messages are never removed from local storage.
class ConversationSummaryWindow {
  const ConversationSummaryWindow({
    required this.messages,
    required this.lastMessageId,
  });

  static const triggerUncoveredMessages = 6;
  static const keepRecentMessages = 8;
  static const maxMessagesPerRequest = 20;

  final List<Message> messages;
  final String lastMessageId;

  static ConversationSummaryWindow? create({
    required ChatThread thread,
    required Iterable<Message> source,
  }) {
    final indexedHistory = <(int, Message)>[];
    var sourceIndex = 0;
    for (final message in source) {
      if (message.threadId == thread.id &&
          message.isRenderable &&
          message.kind != MessageKind.system &&
          !message.interrupted) {
        indexedHistory.add((sourceIndex, message));
      }
      sourceIndex++;
    }
    indexedHistory.sort((a, b) {
      final time = a.$2.createdAt.compareTo(b.$2.createdAt);
      return time != 0 ? time : a.$1.compareTo(b.$1);
    });
    final history = indexedHistory.map((item) => item.$2).toList();
    if (history.isEmpty) return null;

    var start = 0;
    final cursor = thread.summarizedThroughMessageId;
    if (cursor != null) {
      final index = history.indexWhere((message) => message.id == cursor);
      if (index >= 0) {
        start = index + 1;
      }
    }

    final uncoveredCount = history.length - start;
    if (uncoveredCount < triggerUncoveredMessages) return null;
    final end = history.length - keepRecentMessages;
    if (end <= start) return null;
    final selected = history.sublist(
      start,
      (start + maxMessagesPerRequest).clamp(start, end),
    );
    return ConversationSummaryWindow(
      messages: List.unmodifiable(selected),
      lastMessageId: selected.last.id,
    );
  }

  String toTranscript() => jsonEncode([
    for (final message in messages)
      if (message.text.trim().isNotEmpty || message.kind == MessageKind.image)
        {
          'id': message.id,
          'speaker': message.fromAi ? '角色' : '用户',
          'text': _boundedText(
            message.kind == MessageKind.image
                ? '[图片]${message.text.trim().isEmpty ? '' : ' ${message.text}'}'
                : message.text,
          ),
        },
  ]);

  static String _boundedText(String value) {
    final text = value.trim();
    if (text.length <= 3000) return text;
    var prefixEnd = 2200;
    if (text.codeUnitAt(prefixEnd - 1) >= 0xD800 &&
        text.codeUnitAt(prefixEnd - 1) <= 0xDBFF) {
      prefixEnd--;
    }
    var suffixStart = text.length - 700;
    if (text.codeUnitAt(suffixStart) >= 0xDC00 &&
        text.codeUnitAt(suffixStart) <= 0xDFFF) {
      suffixStart++;
    }
    return '${text.substring(0, prefixEnd)}\n…（中间长段省略）…\n${text.substring(suffixStart)}';
  }
}

import '../domain/dialogue.dart';
import '../domain/models.dart';

class RepetitionMatch {
  const RepetitionMatch({
    required this.messageId,
    required this.similarity,
    required this.previousText,
  });

  final String messageId;
  final double similarity;
  final String previousText;
}

class RepetitionGuard {
  const RepetitionGuard._();

  static RepetitionMatch? find({
    required String candidate,
    required Iterable<Message> recentAssistantMessages,
    double threshold = 0.72,
  }) {
    final normalized = _normalize(candidate);
    if (normalized.isEmpty) return null;
    RepetitionMatch? best;
    for (final message in recentAssistantMessages.take(6)) {
      final previous = _normalize(message.text);
      if (previous.isEmpty) continue;
      final similarity = _similarity(normalized, previous);
      if (similarity < threshold) continue;
      if ((normalized.length < 10 || previous.length < 10) &&
          normalized != previous) {
        continue;
      }
      if (best == null || similarity > best.similarity) {
        best = RepetitionMatch(
          messageId: message.id,
          similarity: similarity,
          previousText: message.text,
        );
      }
    }
    return best;
  }

  static double similarity(String a, String b) =>
      _similarity(_normalize(a), _normalize(b));

  static String _normalize(String value) {
    final text = DialogueParser.parse(value)
        .map((part) => part.text)
        .join()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s，。！？；：,.!?;:~～…“”"「」『』（）()*_`#\-]'), '');
    return text;
  }

  static double _similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    if ((a.contains(b) || b.contains(a)) && a.length >= 12 && b.length >= 12) {
      return 0.94;
    }
    final aPairs = _bigrams(a);
    final bPairs = _bigrams(b);
    if (aPairs.isEmpty || bPairs.isEmpty) return 0;
    final intersection = aPairs.intersection(bPairs).length;
    final union = aPairs.union(bPairs).length;
    return union == 0 ? 0 : intersection / union;
  }

  static Set<String> _bigrams(String value) {
    final runes = value.runes.toList();
    if (runes.length < 2) return {value};
    return {
      for (var index = 0; index + 1 < runes.length; index++)
        String.fromCharCodes(runes.sublist(index, index + 2)),
    };
  }
}

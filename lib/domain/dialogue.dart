enum DialogueSegmentKind { narration, speech }

class DialogueSegment {
  const DialogueSegment({required this.kind, required this.text});
  final DialogueSegmentKind kind;
  final String text;
  bool get isRenderable =>
      text.trim().isNotEmpty && !_structureOnly.hasMatch(text);
  static final _structureOnly = RegExp(
    r'''^[\s\u200B-\u200D\uFEFF「」『』“”"'>*_`~#\[\]{}|（）()]+$''',
  );
}

/// Parses actions in Chinese/ASCII parentheses and V1 Markdown narration.
/// Balanced scanning preserves nested actions and streaming partial brackets.
/// Quoted dialogue is consumed before parentheses, so spoken asides are kept.
class DialogueParser {
  const DialogueParser._();
  static List<DialogueSegment> parse(String raw) {
    final text = raw
        .replaceAll(RegExp(r'<think>[\s\S]*?(</think>|$)'), '')
        .replaceAll(
          RegExp(
            r'```[ \t]*(stats|remark|timeline|toy|json)[^\n]*\n[\s\S]*?(```|$)',
          ),
          '',
        )
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    final result = <DialogueSegment>[];
    final speech = StringBuffer();
    void add(DialogueSegmentKind kind, String value) {
      final segment = DialogueSegment(kind: kind, text: value.trim());
      if (segment.isRenderable) result.add(segment);
    }

    void flush() {
      add(DialogueSegmentKind.speech, speech.toString());
      speech.clear();
    }

    const closings = {'（': '）', '(': ')', '「': '」', '『': '』', '“': '”'};
    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (closings.containsKey(ch)) {
        final close = closings[ch]!;
        final narrative = ch == '（' || ch == '(';
        var end = i + 1;
        var depth = 1;
        while (end < text.length) {
          if (text[end] == ch) depth++;
          if (text[end] == close) depth--;
          if (depth == 0) break;
          end++;
        }
        flush();
        add(
          narrative
              ? DialogueSegmentKind.narration
              : DialogueSegmentKind.speech,
          text.substring(i + 1, end),
        );
        i = end < text.length ? end + 1 : end;
      } else if (ch == '*' &&
          (i + 1 >= text.length || text[i + 1] != '*') &&
          (i == 0 || text[i - 1] != '*')) {
        final end = text.indexOf('*', i + 1);
        if (end > i + 1 && !text.substring(i + 1, end).contains('\n')) {
          flush();
          add(DialogueSegmentKind.narration, text.substring(i + 1, end));
          i = end + 1;
        } else {
          speech.write(ch);
          i++;
        }
      } else if (ch == '>' && (i == 0 || text[i - 1] == '\n')) {
        flush();
        final newline = text.indexOf('\n', i);
        final end = newline == -1 ? text.length : newline;
        add(DialogueSegmentKind.narration, text.substring(i + 1, end));
        i = end;
      } else {
        speech.write(ch);
        i++;
      }
    }
    flush();
    return result;
  }
}

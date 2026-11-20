import 'fixtures/sample_data.dart';
import 'package:dreamtide/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 state survives a JSON round trip', () {
    final source = buildSeedData();
    final restored = AppData.decode(source.encode());

    expect(restored.schemaVersion, 2);
    expect(restored.characters.length, source.characters.length);
    expect(restored.threads.length, source.threads.length);
    expect(restored.messages.length, source.messages.length);
    expect(restored.memories.length, source.memories.length);
    expect(restored.moments.length, source.moments.length);
  });

  test('empty messages are never renderable', () {
    final message = Message(
      id: 'empty',
      threadId: 'thread',
      senderId: 'character',
      senderName: '顾言',
      text: '  \n ',
      createdAt: DateTime.now(),
      fromAi: true,
    );

    expect(message.isRenderable, isFalse);
  });

  test('relationship and thread helpers resolve the bound character', () {
    final data = buildSeedData();
    final thread = data.threads.firstWhere((e) => e.id == 'thread_gu');
    final relationship = data.relationshipForThread(thread);

    expect(relationship, isNotNull);
    expect(data.characterForRelationship(relationship!)?.name, '顾言');
    expect(data.personaById(relationship.personaId)?.name, '林澈');
  });
}

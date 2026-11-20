import 'package:dreamtide/ai/context_assembler.dart';
import 'fixtures/sample_data.dart';
import 'package:dreamtide/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assembler = ContextAssembler();

  test(
    'prompt prioritizes hard boundaries and includes retrieved memories',
    () {
      final data = buildSeedData();
      final thread = data.threads.firstWhere((e) => e.id == 'thread_gu');
      final bundle = assembler.assemble(
        data: data,
        thread: thread,
        userInput: '今天工作很累，晚上想和你多待一会儿',
      );

      final system = bundle.messages.first.content;
      expect(bundle.messages.first.role, 'system');
      expect(system.indexOf('不可覆盖的平台安全规则'), lessThan(system.indexOf('AI 角色')));
      expect(system.indexOf('禁止主题'), lessThan(system.indexOf('长期记忆')));
      expect(system, contains('亲密前先确认'));
      expect(bundle.usedMemoryIds, contains('mem_3'));
      expect(bundle.messages.last.content, contains('工作很累'));
    },
  );

  test('pinned boundary memories rank before recent non-pinned memories', () {
    final now = DateTime.now();
    final memories = [
      MemoryItem(
        id: 'recent',
        relationshipId: 'rel',
        type: MemoryType.experience,
        title: '刚刚发生',
        content: '喝水',
        createdAt: now,
      ),
      MemoryItem(
        id: 'boundary',
        relationshipId: 'rel',
        type: MemoryType.boundary,
        title: '不可越过',
        content: '必须先确认',
        createdAt: now.subtract(const Duration(days: 20)),
        pinned: true,
      ),
    ];

    final result = assembler.retrieveMemories(
      all: memories,
      query: '今天',
      limit: 2,
    );
    expect(result.first.id, 'boundary');
  });
}

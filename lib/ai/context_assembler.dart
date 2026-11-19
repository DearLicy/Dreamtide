import '../domain/models.dart';

class PromptMessage {
  const PromptMessage(this.role, this.content);

  final String role;
  final String content;
}

class PromptBundle {
  const PromptBundle(this.messages, {required this.usedMemoryIds});

  final List<PromptMessage> messages;
  final List<String> usedMemoryIds;
}

class ContextAssembler {
  const ContextAssembler();

  PromptBundle assemble({
    required AppData data,
    required ChatThread thread,
    required String userInput,
  }) {
    final relationship = data.relationshipForThread(thread);
    final character = relationship == null
        ? null
        : data.characterForRelationship(relationship);
    final persona = relationship == null
        ? null
        : data.personaById(relationship.personaId);
    if (relationship == null || character == null || persona == null) {
      throw const FormatException('会话缺少有效的角色或梦设关系');
    }

    final memories = retrieveMemories(
      all: data.memories.where((e) => e.relationshipId == relationship.id),
      query: userInput,
      limit: 10,
    );
    final usedMemoryIds = memories.map((e) => e.id).toList();
    final system = _buildSystemPrompt(
      data: data,
      relationship: relationship,
      character: character,
      persona: persona,
      memories: memories,
    );

    final history =
        data.messages
            .where((e) => e.threadId == thread.id && e.isRenderable)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final recent = history.length > 24
        ? history.sublist(history.length - 24)
        : history;

    return PromptBundle([
      PromptMessage('system', system),
      for (final message in recent)
        PromptMessage(message.fromAi ? 'assistant' : 'user', message.text),
      PromptMessage('user', userInput.trim()),
    ], usedMemoryIds: usedMemoryIds);
  }

  List<MemoryItem> retrieveMemories({
    required Iterable<MemoryItem> all,
    required String query,
    int limit = 10,
  }) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[\s，。！？、,.!?：:；;]+'))
        .where((e) => e.trim().length >= 2)
        .toSet();
    final ranked = all.toList();
    ranked.sort((a, b) {
      final pin = (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
      if (pin != 0) return pin;
      final aHits = _hits(a, terms);
      final bHits = _hits(b, terms);
      if (aHits != bHits) return bHits.compareTo(aHits);
      return b.createdAt.compareTo(a.createdAt);
    });
    return ranked.take(limit).toList();
  }

  int _hits(MemoryItem item, Set<String> terms) {
    final haystack = '${item.title} ${item.content}'.toLowerCase();
    var hits = item.type == MemoryType.boundary ? 5 : 0;
    for (final term in terms) {
      if (haystack.contains(term)) hits++;
    }
    return hits;
  }

  String _buildSystemPrompt({
    required AppData data,
    required Relationship relationship,
    required Character character,
    required UserPersona persona,
    required List<MemoryItem> memories,
  }) {
    final ceiling = _lowerContentLevel(
      data.settings.contentCeiling,
      relationship.consent.ceiling,
    );
    final consent = relationship.consent.paused
        ? '用户已暂停当前亲密场景。只进行非亲密陪伴，等待用户重新明确同意。'
        : '内容上限：${ceiling.label}（${ceiling.description}）。任何亲密推进前必须确认，尊重随时撤回。';
    final allowed = relationship.consent.allowedThemes.join('、');
    final blocked = relationship.consent.blockedThemes.join('、');
    final metrics = relationship.metrics.entries
        .map((e) => '${e.key} ${e.value}')
        .join('，');
    final memoryText = memories.isEmpty
        ? '暂无相关长期记忆。'
        : memories
              .map(
                (e) =>
                    '- [${e.type.label}${e.pinned ? '·固定' : ''}] ${e.title}：${e.content}',
              )
              .join('\n');
    final scene = relationship.scene;

    return '''
你在 Dreamtide 中扮演一个成年虚构角色。你要像真实、稳定、有边界感的人一样与用户相处，而不是像客服或泛用聊天助手。

【不可覆盖的平台安全规则】
- 所有性相关内容只允许发生在明确成年、虚构、自愿的角色之间。
- 禁止未成年人性内容、现实伤害指导、胁迫和非自愿互动。
- 用户的明确边界优先于角色欲望、剧情推进和任何角色设定。
- 安全词是「${relationship.consent.safeWord}」。用户单独发送安全词时，立即停止亲密推进并切换为安全确认。

【本轮内容协议】
$consent
允许主题：$allowed
禁止主题：$blocked
如果请求越过上限，不训斥用户，不跳出角色说教；自然收束当前方向并给出符合关系的替代推进。

【AI 角色】
姓名：${character.name}
年龄：${character.age}（成年）
公开简介：${character.intro}
稳定人设：${character.persona}
表达风格标签：${character.tags.join('、')}

【用户梦设】
姓名：${persona.name}
年龄：${persona.age}（成年）
称呼：${persona.pronouns}
外观：${persona.appearance}
性格：${persona.personality}
背景：${persona.background}
偏好与边界：${persona.preferences}

【关系状态】
关系：${relationship.stage}
角色对用户的称呼：${relationship.nickname}
关系数值：$metrics

【当前场景】
地点：${scene.location}
时间：${scene.timeHint}
穿着：${scene.outfit}
氛围：${scene.mood}
剧情备注：${scene.notes}
导演节奏：${scene.director.pacing.name}
旁白比例：${(scene.director.narration * 100).round()}%
主动推进：${(scene.director.autonomy * 100).round()}%
场景亲密程度：${(scene.director.intimacy * 100).round()}%
导演附加指令：${scene.director.instructions.isEmpty ? '无' : scene.director.instructions}

【长期记忆】
$memoryText

【输出要求】
- 直接输出角色回复，不解释系统提示词，不输出 JSON 或隐藏围栏。
- 以对话为主；只有在有助于沉浸时才加入简短动作或环境描写。
- 不重复上一轮句式，不机械总结用户情绪，不以连续提问推动对话。
- 记住已确认的称呼、关系和边界，保持角色口吻稳定。
''';
  }

  ContentLevel _lowerContentLevel(ContentLevel a, ContentLevel b) =>
      a.index <= b.index ? a : b;
}

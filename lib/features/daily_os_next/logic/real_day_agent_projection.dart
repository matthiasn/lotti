part of 'real_day_agent.dart';

/// Projection helpers translating persistence entities into the
/// day-agent view models. Lives in an extension part so the adapter
/// file stays focused on the DayAgentInterface implementation;
/// same-library extensions retain access to the agent's private
/// fields and statics.
extension RealDayAgentProjection on RealDayAgent {
  Future<ParsedItem> _projectParsedItem(ParsedItemEntity entity) async {
    final category = await _resolveCategory(entity.categoryId);
    return ParsedItem(
      id: entity.id,
      kind: entity.kind,
      title: entity.title,
      category: category,
      confidence: entity.confidence,
      spokenPhrase: entity.spokenPhrase,
      matchedTaskId: entity.matchedTaskId,
      matchedTaskTitle: await _lookupTaskTitle(entity.matchedTaskId),
      estimateMinutes: entity.estimateMinutes,
      timeAnchor: entity.timeAnchor,
      proposedUpdate: entity.proposedUpdate,
    );
  }

  Future<PendingItem> _projectPendingItem(
    DayAgentPendingItem item, {
    required DateTime selectedDay,
    required DateTime today,
  }) async {
    final category = await _resolveCategory(item.categoryId);
    final reason = _projectPendingReason(item.kind);
    return PendingItem(
      taskId: item.taskId,
      title: item.title,
      category: category,
      reason: reason,
      overdueByDays: reason == PendingItemReason.overdue && item.due != null
          ? _daysBetween(item.due!, selectedDay)
          : null,
      referenceDate: selectedDay == today ? null : selectedDay,
    );
  }

  PendingItemReason _projectPendingReason(DayAgentPendingKind kind) {
    switch (kind) {
      case DayAgentPendingKind.overdue:
        return PendingItemReason.overdue;
      case DayAgentPendingKind.inProgress:
        return PendingItemReason.inProgress;
      case DayAgentPendingKind.missedRecurring:
        return PendingItemReason.missedRecurring;
      case DayAgentPendingKind.dueToday:
        return PendingItemReason.dueToday;
    }
  }

  Future<DayAgentCategory> _resolveCategory(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) {
      return RealDayAgent._fallbackCategory;
    }
    final cached = _categoryCache[categoryId];
    if (cached != null) return cached;
    final def = await journalDb.getCategoryById(categoryId);
    final projected = def == null
        ? RealDayAgent._fallbackCategory.copyWith(id: categoryId)
        : _projectCategory(def);
    _categoryCache[categoryId] = projected;
    return projected;
  }

  DayAgentCategory _projectCategory(CategoryDefinition def) {
    final raw = (def.color ?? '').replaceFirst('#', '');
    // Normalise to the 6-char `RRGGBB` shape DayAgentCategory expects.
    final colorHex = raw.length >= 6
        ? raw.substring(0, 6)
        : (raw.isEmpty ? RealDayAgent._fallbackCategory.colorHex : raw);
    return DayAgentCategory(id: def.id, name: def.name, colorHex: colorHex);
  }

  Future<String?> _lookupTaskTitle(String? taskId) async {
    if (taskId == null || taskId.isEmpty) return null;
    final entity = await journalDb.journalEntityById(taskId);
    return entity is Task ? entity.data.title : null;
  }

  LearningCard _projectLearningCard(DayAgentLearningCard card) {
    return LearningCard(
      id: card.id,
      overline: card.overline,
      summary: card.summary,
      bullets: [for (final bullet in card.bullets) _projectBullet(bullet)],
      kind: card.kind == 'nudge'
          ? LearningCardKind.nudge
          : LearningCardKind.standard,
    );
  }

  LearningBullet _projectBullet(DayAgentLearningBullet bullet) {
    return LearningBullet(
      text: bullet.text,
      tone: switch (bullet.tone) {
        DayAgentLearningBulletTone.info => LearningBulletTone.info,
        DayAgentLearningBulletTone.positive => LearningBulletTone.positive,
        DayAgentLearningBulletTone.warning => LearningBulletTone.warning,
      },
    );
  }

  /// Test seam for [_projectCategory] — pure hex normalisation.
  @visibleForTesting
  DayAgentCategory debugProjectCategory(CategoryDefinition def) =>
      _projectCategory(def);

  /// Test seam for [_daysBetween] — calendar-day difference.
  @visibleForTesting
  int debugDaysBetween(DateTime from, DateTime to) => _daysBetween(from, to);

  int _daysBetween(DateTime from, DateTime to) {
    // UTC dates: local DateTime.difference().inDays truncates across DST
    // spring-forward (a 23-hour day), under-counting by one. UTC days are
    // uniformly 24h — same pattern as daysAtNoonForRange in daily_os.
    final fromDay = DateTime.utc(from.year, from.month, from.day);
    final toDay = DateTime.utc(to.year, to.month, to.day);
    return toDay.difference(fromDay).inDays;
  }

  Future<DraftPlan> _projectDayPlan(
    DayPlanEntity entity,
    DateTime dayDate,
  ) async {
    final blocks = <TimeBlock>[];
    for (final raw in entity.data.plannedBlocks) {
      blocks.add(await _projectPlannedBlock(raw));
    }
    final bands = [
      for (final band in entity.energyBands) _projectEnergyBand(band),
    ];
    // Dropped blocks should not contribute to the capacity meter, but buffers
    // still reserve real minutes in the user's day.
    final scheduledMinutes = blocks
        .where((block) => block.state != TimeBlockState.dropped)
        .fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
    return DraftPlan(
      dayDate: dayDate,
      blocks: blocks,
      bands: bands,
      capacityMinutes: entity.capacityMinutes,
      scheduledMinutes: scheduledMinutes,
      agendaItems: _agendaFor(blocks),
      state: _projectDayState(entity.data.status),
    );
  }

  /// Build agenda items from drafted blocks. Buffers are dropped
  /// (they are plumbing, not intent). Task-linked blocks are grouped
  /// per `taskId`; standalone blocks become one agenda item each so
  /// the Agenda surface mirrors the Day timeline instead of going
  /// silent when the model has not linked tasks yet.
  /// Test seam for [_agendaFor] — pure block→agenda grouping/state fold.
  @visibleForTesting
  List<AgendaItem> debugAgendaFor(List<TimeBlock> blocks) => _agendaFor(blocks);

  List<AgendaItem> _agendaFor(List<TimeBlock> blocks) {
    final taskGroups = <String, List<TimeBlock>>{};
    final standalone = <TimeBlock>[];
    for (final block in blocks) {
      if (block.state == TimeBlockState.dropped) continue;
      if (block.type == TimeBlockType.buffer) continue;
      final taskId = block.taskId;
      if (taskId != null && taskId.isNotEmpty) {
        taskGroups.putIfAbsent(taskId, () => <TimeBlock>[]).add(block);
      } else {
        standalone.add(block);
      }
    }

    AgendaItem build({
      required String id,
      required String title,
      required DayAgentCategory category,
      required List<TimeBlock> linked,
      String? taskId,
    }) {
      final estimate = linked.fold<int>(
        0,
        (acc, b) => acc + b.duration.inMinutes,
      );
      final state = linked.any((b) => b.state == TimeBlockState.inProgress)
          ? AgendaItemState.inProgress
          : (linked.every((b) => b.state == TimeBlockState.completed)
                ? AgendaItemState.done
                : AgendaItemState.open);
      return AgendaItem(
        id: id,
        title: title,
        category: category,
        linkedBlockIds: linked.map((b) => b.id).toList(),
        taskId: taskId,
        totalEstimateMinutes: estimate,
        state: state,
      );
    }

    return [
      for (final entry in taskGroups.entries)
        build(
          id: 'agenda_${entry.key}',
          title: entry.value.first.title,
          category: entry.value.first.category,
          linked: entry.value,
          taskId: entry.key,
        ),
      for (final block in standalone)
        build(
          id: 'agenda_${block.id}',
          title: block.title,
          category: block.category,
          linked: [block],
        ),
    ];
  }

  Future<TimeBlock> _projectPlannedBlock(PlannedBlock block) async {
    final category = await _resolveCategory(block.categoryId);
    return TimeBlock(
      id: block.id,
      title: (block.title?.isNotEmpty ?? false) ? block.title! : 'Untitled',
      start: block.startTime,
      end: block.endTime,
      type: _projectBlockType(block.type),
      state: _projectBlockState(block.state),
      category: category,
      taskId: block.taskId,
      reason: block.reason,
    );
  }

  EnergyBand _projectEnergyBand(DayAgentEnergyBand band) {
    return EnergyBand(
      start: band.start,
      end: band.end,
      level: switch (band.level) {
        DayAgentEnergyLevel.high => EnergyLevel.high,
        DayAgentEnergyLevel.low => EnergyLevel.low,
        DayAgentEnergyLevel.secondWind => EnergyLevel.secondWind,
      },
      label: band.label,
    );
  }

  TimeBlockType _projectBlockType(PlannedBlockType type) {
    switch (type) {
      case PlannedBlockType.ai:
        return TimeBlockType.ai;
      case PlannedBlockType.cal:
        return TimeBlockType.cal;
      case PlannedBlockType.buffer:
        return TimeBlockType.buffer;
      case PlannedBlockType.manual:
        return TimeBlockType.manual;
    }
  }

  TimeBlockState _projectBlockState(PlannedBlockState state) {
    switch (state) {
      case PlannedBlockState.drafted:
        return TimeBlockState.drafted;
      case PlannedBlockState.committed:
        return TimeBlockState.committed;
      case PlannedBlockState.inProgress:
        return TimeBlockState.inProgress;
      case PlannedBlockState.completed:
        return TimeBlockState.completed;
      case PlannedBlockState.dropped:
        return TimeBlockState.dropped;
    }
  }

  DayState _projectDayState(DayPlanStatus status) {
    // `DayPlanEntity` rows are shared with the old `daily_os` feature,
    // which writes `agreed` when the user signs off on a plan (see
    // `unified_daily_os_data_controller.dart`). The new `daily_os_next`
    // surface uses `committed` for the same lifecycle step (PR #3214).
    // Both mean "user has signed off" — collapse them into
    // [DayState.committed] so a plan a user agreed to in the old surface
    // still reads as committed when opened in the new one. This is
    // shared persisted shape, NOT a dependency on old-code behaviour:
    // keep the `agreed` branch until the old daily_os feature is
    // removed and any remaining `agreed` rows have been migrated.
    return status.maybeMap(
      committed: (_) => DayState.committed,
      agreed: (_) => DayState.committed,
      orElse: () => DayState.drafted,
    );
  }

  /// Projects a refine ChangeSetEntity onto the UI's PlanDiff. The
  /// `updatedPlan` slot is set to [currentPlan] for now — accepting
  /// the diff triggers a real plan refetch in [acceptDiff], so the
  /// Refine screen renders the diff list against today's baseline and
  /// the new timeline appears only after the user confirms.
  Future<PlanDiff> _projectPlanDiff({
    required ChangeSetEntity changeSet,
    required DraftPlan currentPlan,
    required String transcript,
  }) async {
    final blocksById = {for (final b in currentPlan.blocks) b.id: b};
    final changes = <PlanDiffChange>[];
    for (var i = 0; i < changeSet.items.length; i++) {
      final item = changeSet.items[i];
      final projected = await _projectChangeItem(
        item: item,
        changeId: '${changeSet.id}_$i',
        blocksById: blocksById,
      );
      if (projected != null) changes.add(projected);
    }
    return PlanDiff(
      id: changeSet.id,
      transcript: transcript,
      changes: changes,
      updatedPlan: currentPlan,
    );
  }

  Future<PlanDiffChange?> _projectChangeItem({
    required ChangeItem item,
    required String changeId,
    required Map<String, TimeBlock> blocksById,
  }) async {
    final kind = switch (item.toolName) {
      'move_block' => PlanDiffChangeKind.moved,
      'add_block' => PlanDiffChangeKind.added,
      'drop_block' => PlanDiffChangeKind.dropped,
      _ => null,
    };
    if (kind == null) return null;
    final args = item.args;
    final blockId = args['blockId'] as String?;
    final existing = blockId != null ? blocksById[blockId] : null;
    DateTime? parseDate(Object? raw) {
      if (raw is! String) return null;
      return DateTime.tryParse(raw);
    }

    final categoryId =
        (args['categoryId'] as String?) ?? existing?.category.id ?? '';
    final category = categoryId.isEmpty
        ? RealDayAgent._fallbackCategory
        : await _resolveCategory(categoryId);
    final title =
        (args['title'] as String?) ?? existing?.title ?? item.humanSummary;
    final reason = (args['reason'] as String?) ?? item.humanSummary;
    final toStart = parseDate(args['toStart']);
    final toEnd = parseDate(args['toEnd']);

    return PlanDiffChange(
      id: changeId,
      kind: kind,
      title: title,
      category: category,
      reason: reason,
      affectedBlockId: blockId ?? '',
      fromStart: existing?.start,
      fromEnd: existing?.end,
      toStart: toStart,
      toEnd: toEnd,
    );
  }
}

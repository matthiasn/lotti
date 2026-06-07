part of 'change_set_builder.dart';

/// Batch-tool explosion and redundancy/summary helpers for
/// [ChangeSetBuilder] — splits array-shaped tool calls into individual
/// [ChangeItem]s with per-element redundancy suppression and human
/// summaries.
extension ChangeSetBatchExplosion on ChangeSetBuilder {
  /// Explode a batch tool call into individual [ChangeItem] entries.
  ///
  /// [toolName] must be in [AgentToolRegistry.explodedBatchTools].
  /// [args] must contain the array key specified in the registry.
  ///
  /// Each array element becomes a separate item with its own human summary.
  /// The [summaryPrefix] is prepended to each element's description.
  ///
  /// Returns a [BatchAddResult] indicating how many items were added and how
  /// many were skipped (non-map elements).
  Future<BatchAddResult> addBatchItem({
    required String toolName,
    required Map<String, dynamic> args,
    required String summaryPrefix,
    String? groupId,
  }) async {
    final arrayKey = AgentToolRegistry.explodedBatchTools[toolName];
    if (arrayKey == null) {
      // Not a known batch tool — fall back to a single item.
      await addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (batch)',
      );
      return const BatchAddResult(added: 1, skipped: 0);
    }

    final array = args[arrayKey];
    if (array is! List || array.isEmpty) {
      // Empty or invalid array — skip without queuing a placeholder.
      // The caller (strategy) will format an appropriate LLM response.
      return const BatchAddResult(added: 0, skipped: 0);
    }

    // Derive the singular tool name by replacing 'add_multiple_' with 'add_'
    // and 'update_checklist_items' with 'update_checklist_item'.
    final singularToolName = _singularize(toolName);

    // Only resolve existing titles when this is an add-checklist batch.
    final isAddBatch = singularToolName == TaskAgentToolNames.addChecklistItem;
    final existingTitles = isAddBatch ? await _resolveExistingTitles() : null;

    // Resolve existing label IDs when this is a label-assignment batch.
    final isLabelBatch = singularToolName == TaskAgentToolNames.assignTaskLabel;
    final existingLabelIds = isLabelBatch
        ? await _resolveExistingLabelIds()
        : null;

    // For migration batch tools, inject top-level keys (targetTaskId) into
    // copies of each child element so singular items are self-contained and
    // dispatchable after explosion. We copy to avoid mutating caller data.
    final isMigrateBatch = toolName == TaskAgentToolNames.migrateChecklistItems;
    final targetTaskIdForMigration = isMigrateBatch
        ? args['targetTaskId']
        : null;

    // Seed a within-wake fingerprint set from items already queued in this
    // builder — the batch path must dedupe identical `(toolName, args)`
    // elements that slip past title/state/label redundancy checks (e.g.
    // the LLM repeating the same `update_checklist_item` three times, or
    // two back-to-back batch calls carrying the same element). Without
    // this guard the item list gets duplicate rows that downstream UI
    // dedup cannot collapse, because each row stays a distinct
    // ChangeItem at the persistence layer.
    final queuedFingerprints = _items.map(ChangeItem.fingerprint).toSet();
    final queuedDisplayKeys = {
      for (final item in _items)
        if (ChangeItem.displayDuplicateKey(item) case final String key) key,
    };

    var added = 0;
    var skipped = 0;
    var redundant = 0;
    final redundantDetails = <String>[];
    for (var element in array) {
      if (element is Map<String, dynamic>) {
        // Inject targetTaskId into a copy for migration items.
        if (targetTaskIdForMigration is String) {
          element = {...element, 'targetTaskId': targetTaskIdForMigration};
        }
        // Check for redundant add_checklist_item proposals (title already
        // exists on the task or was already proposed in this wake).
        if (existingTitles != null) {
          final addRedundancyDetail = _checkAddRedundancy(
            singularToolName,
            element,
            existingTitles,
          );
          if (addRedundancyDetail != null) {
            redundant++;
            redundantDetails.add(addRedundancyDetail);
            continue;
          }
        }

        // Check for redundant label assignments (already on the task).
        if (existingLabelIds != null) {
          final labelRedundancyDetail = await _checkLabelRedundancy(
            element,
            existingLabelIds,
          );
          if (labelRedundancyDetail != null) {
            redundant++;
            redundantDetails.add(labelRedundancyDetail);
            continue;
          }
        }

        // Resolve state once per item to avoid redundant DB lookups and
        // duplicate error logging.
        final itemId = element['id'];
        final resolvedState = itemId is String && !isLabelBatch
            ? await _resolveState(itemId)
            : null;

        // Check for redundant update_checklist_item proposals.
        final redundancyDetail = _checkRedundancy(
          singularToolName,
          element,
          resolvedState,
        );
        if (redundancyDetail != null) {
          redundant++;
          redundantDetails.add(redundancyDetail);
          continue;
        }

        // Structural fingerprint dedup: drop elements whose `(toolName,
        // args)` already matches a queued item. Catches identical LLM
        // repeats that survived the title/state/label guards above —
        // e.g. a second check-off of the same item id in the same
        // batch, or the same `assign_task_labels` array element twice.
        final fingerprint = ChangeItem.fingerprintFromParts(
          singularToolName,
          element,
        );
        if (queuedFingerprints.contains(fingerprint)) {
          redundant++;
          redundantDetails.add(
            'identical $singularToolName proposal already queued in this '
            'wake — skipped.',
          );
          continue;
        }

        final summary = isLabelBatch
            ? await _generateLabelSummary(element)
            : _generateItemSummary(
                singularToolName,
                element,
                summaryPrefix,
                resolvedState: resolvedState,
              );
        final displayKey = ChangeItem.displayDuplicateKeyFromParts(
          singularToolName,
          summary,
          args: element,
        );
        if (displayKey != null && queuedDisplayKeys.contains(displayKey)) {
          redundant++;
          redundantDetails.add(
            'identical visible $singularToolName proposal already queued in '
            'this wake — skipped.',
          );
          continue;
        }
        queuedFingerprints.add(fingerprint);
        if (displayKey != null) queuedDisplayKeys.add(displayKey);

        _items.add(
          ChangeItem(
            toolName: singularToolName,
            args: element,
            humanSummary: summary,
            groupId: groupId,
          ),
        );

        // Track the title in the existing set so that subsequent items in
        // the same batch with the same title are caught as duplicates.
        if (existingTitles != null) {
          final title = element['title'];
          if (title is String) {
            final normalized = title.trim().toLowerCase();
            if (normalized.isNotEmpty) {
              existingTitles.add(normalized);
            }
          }
        }

        // Track the label ID so subsequent items in the same batch
        // with the same ID are caught as duplicates.
        if (existingLabelIds != null) {
          final labelId = element['id'];
          if (labelId is String) {
            existingLabelIds.add(labelId);
          }
        }
        added++;
      } else {
        skipped++;
      }
    }
    return BatchAddResult(
      added: added,
      skipped: skipped,
      redundant: redundant,
      redundantDetails: redundantDetails,
    );
  }

  /// Convert batch tool name to a singular form for individual items.
  static String _singularize(String toolName) => switch (toolName) {
    TaskAgentToolNames.addMultipleChecklistItems =>
      TaskAgentToolNames.addChecklistItem,
    TaskAgentToolNames.updateChecklistItems =>
      TaskAgentToolNames.updateChecklistItem,
    TaskAgentToolNames.assignTaskLabels => TaskAgentToolNames.assignTaskLabel,
    TaskAgentToolNames.migrateChecklistItems =>
      TaskAgentToolNames.migrateChecklistItem,
    _ => throw ArgumentError(
      'Unsupported batch tool for singularization: $toolName. '
      'Add an explicit mapping.',
    ),
  };

  /// Generate a human-readable summary for a single exploded item.
  ///
  /// [resolvedState] is the pre-resolved checklist item state (if available).
  /// Callers should resolve the state once and pass it here to avoid redundant
  /// DB lookups.
  String _generateItemSummary(
    String singularToolName,
    Map<String, dynamic> args,
    String prefix, {
    ({String? title, bool? isChecked, bool? isArchived})? resolvedState,
  }) {
    // Archival reads clearest as its own verb, regardless of whether the
    // title travels in the args or is resolved from the item id.
    final isArchived = args['isArchived'];

    // For checklist items, use the title.
    final title = args['title'];
    if (title is String && title.isNotEmpty) {
      if (singularToolName.startsWith('add_')) {
        return 'Add: "$title"';
      }
      if (singularToolName.startsWith('update_')) {
        if (isArchived is bool) {
          final action = isArchived ? 'Archive' : 'Restore';
          return '$action: "$title"';
        }
        final isChecked = args['isChecked'];
        if (isChecked is bool) {
          final action = isChecked ? 'Check' : 'Uncheck';
          return '$action: "$title"';
        }
        return 'Update: "$title"';
      }
    }

    // For updates by ID only (no title in args) — use pre-resolved state.
    final id = args['id'];
    if (id is String) {
      final resolvedTitle = resolvedState?.title;
      if (isArchived is bool) {
        final action = isArchived ? 'Archive' : 'Restore';
        if (resolvedTitle != null) {
          return '$action: "$resolvedTitle"';
        }
        return '$action item ${_truncateId(id)}';
      }
      final isChecked = args['isChecked'];
      if (isChecked is bool) {
        final action = isChecked ? 'Check off' : 'Uncheck';
        if (resolvedTitle != null) {
          return '$action: "$resolvedTitle"';
        }
        return '$action item ${_truncateId(id)}';
      }
      if (resolvedTitle != null) {
        return '$prefix: "$resolvedTitle"';
      }
      return '$prefix item ${_truncateId(id)}';
    }

    return '$prefix item';
  }

  /// Resolve a checklist item's current state via the injected resolver.
  ///
  /// Returns `null` if no resolver is set or the item cannot be found.
  Future<({String? title, bool? isChecked, bool? isArchived})?> _resolveState(
    String itemId,
  ) async {
    final resolver = checklistItemStateResolver;
    if (resolver == null) return null;
    try {
      return await resolver(itemId);
    } catch (e, s) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'failed to resolve checklist item state for '
            '${DomainLogger.sanitizeId(itemId)}',
        stackTrace: s,
      );
      return null;
    }
  }

  /// Resolve existing checklist titles, initialising the cache on first call.
  ///
  /// The returned set is the canonical `_cachedExistingTitles` instance —
  /// callers may mutate it (e.g. adding titles for same-wake dedup) and the
  /// additions will be visible to subsequent calls without re-scanning.
  Future<Set<String>> _resolveExistingTitles() async {
    if (_cachedExistingTitles != null) return _cachedExistingTitles!;

    final resolver = existingChecklistTitlesResolver;
    if (resolver != null) {
      try {
        // Copy to a mutable set so callers can add in-wake titles.
        _cachedExistingTitles = {...await resolver()};
        domainLogger?.log(
          LogDomain.agentWorkflow,
          'resolved ${_cachedExistingTitles!.length} existing checklist '
          'title(s) for dedup',
        );
      } catch (e, s) {
        domainLogger?.error(
          LogDomain.agentWorkflow,
          e,
          message: 'failed to resolve existing checklist titles',
          stackTrace: s,
        );
        _cachedExistingTitles = {};
      }
    } else {
      _cachedExistingTitles = {};
    }

    return _cachedExistingTitles!;
  }

  /// Check whether an `add_checklist_item` proposal is redundant because
  /// an item with the same title (case-insensitive) already exists on the
  /// task.
  ///
  /// Returns a human-readable detail string if redundant, or `null` if the
  /// item should be kept.
  static String? _checkAddRedundancy(
    String singularToolName,
    Map<String, dynamic> args,
    Set<String> existingTitles,
  ) {
    if (singularToolName != TaskAgentToolNames.addChecklistItem) {
      return null;
    }

    final title = args['title'];
    if (title is! String) return null;
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (existingTitles.contains(normalized)) {
      return '"$title" already exists on the task';
    }
    return null;
  }

  /// Check whether an `update_checklist_item` proposal is redundant.
  ///
  /// Returns a human-readable detail string if the item is redundant (should
  /// be suppressed), or `null` if the item should be kept.
  ///
  /// An update is redundant when:
  /// - The proposed `isChecked` matches the current `isChecked`, AND
  /// - No title change is proposed (or the proposed title matches current).
  ///
  /// Conservative: if the resolver is unavailable or the item is not found,
  /// the item is kept (returns `null`).
  ///
  /// [currentState] is the pre-resolved checklist item state.
  static String? _checkRedundancy(
    String singularToolName,
    Map<String, dynamic> args,
    ({String? title, bool? isChecked, bool? isArchived})? currentState,
  ) {
    if (singularToolName != TaskAgentToolNames.updateChecklistItem) {
      return null;
    }

    final itemId = args['id'];
    if (itemId is! String) return null;
    if (currentState == null) return null; // Item not found — keep it.

    final proposedIsChecked = args['isChecked'];
    final proposedTitle = args['title'];
    final proposedIsArchived = args['isArchived'];

    // Determine whether each field represents an actual change.
    final isCheckedChanging =
        proposedIsChecked is bool &&
        (currentState.isChecked == null ||
            proposedIsChecked != currentState.isChecked);

    final isTitleChanging =
        proposedTitle is String &&
        proposedTitle.isNotEmpty &&
        proposedTitle != currentState.title;

    final isArchivedChanging =
        proposedIsArchived is bool &&
        (currentState.isArchived == null ||
            proposedIsArchived != currentState.isArchived);

    // If any field is changing, the proposal is not redundant.
    if (isCheckedChanging || isTitleChanging || isArchivedChanging) {
      return null;
    }

    // Only suppress if the proposal contains at least one valid field.
    final hasValidProposal =
        proposedIsChecked is bool ||
        proposedIsArchived is bool ||
        (proposedTitle is String && proposedTitle.isNotEmpty);
    if (!hasValidProposal) {
      return null; // Malformed — keep it defensively.
    }

    // At this point the update is redundant.
    final displayTitle = currentState.title ?? _truncateId(itemId);
    if (proposedIsArchived is bool && proposedIsChecked is! bool) {
      final archivedLabel = currentState.isArchived == true
          ? 'archived'
          : 'not archived';
      return '"$displayTitle" is already $archivedLabel';
    }
    final checkedLabel = currentState.isChecked == true
        ? 'checked'
        : 'unchecked';
    return '"$displayTitle" is already $checkedLabel';
  }

  /// Resolve existing label IDs, initialising the cache on first call.
  Future<Set<String>> _resolveExistingLabelIds() async {
    if (_cachedExistingLabelIds != null) return _cachedExistingLabelIds!;

    final resolver = existingLabelIdsResolver;
    if (resolver != null) {
      try {
        _cachedExistingLabelIds = {...await resolver()};
      } catch (e, s) {
        domainLogger?.error(
          LogDomain.agentWorkflow,
          e,
          message: 'failed to resolve existing label IDs',
          stackTrace: s,
        );
        _cachedExistingLabelIds = {};
      }
    } else {
      _cachedExistingLabelIds = {};
    }

    return _cachedExistingLabelIds!;
  }

  /// Check whether an `assign_task_label` proposal is redundant because
  /// the label is already assigned to the task.
  ///
  /// Returns a human-readable detail string if redundant, or `null` if the
  /// item should be kept.
  Future<String?> _checkLabelRedundancy(
    Map<String, dynamic> args,
    Set<String> existingLabelIds,
  ) async {
    final labelId = args['id'];
    if (labelId is! String) return null;
    if (!existingLabelIds.contains(labelId)) return null;

    final labelName = await _resolveLabelName(labelId);
    final display = labelName ?? _truncateId(labelId);
    return 'Label "$display" is already assigned';
  }

  /// Generate a human-readable summary for a single exploded label item.
  Future<String> _generateLabelSummary(Map<String, dynamic> args) async {
    final labelId = args['id'];
    final confidence = args['confidence'];
    final labelName = labelId is String
        ? await _resolveLabelName(labelId)
        : null;
    final display =
        labelName ?? (labelId is String ? _truncateId(labelId) : '?');
    final confidenceSuffix =
        confidence is String &&
            const ['very_high', 'high', 'medium', 'low'].contains(confidence)
        ? ' ($confidence)'
        : '';
    return 'Assign label: "$display"$confidenceSuffix';
  }

  /// Resolve a label's human-readable name via the injected resolver.
  Future<String?> _resolveLabelName(String labelId) async {
    final resolver = labelNameResolver;
    if (resolver == null) return null;
    try {
      return await resolver(labelId);
    } catch (e, s) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'failed to resolve label name for '
            '${DomainLogger.sanitizeId(labelId)}',
        stackTrace: s,
      );
      return null;
    }
  }

  /// Truncate a UUID to a short prefix for display as a fallback.
  static String _truncateId(String id) =>
      id.length > 8 ? '${id.substring(0, 8)}…' : id;
}

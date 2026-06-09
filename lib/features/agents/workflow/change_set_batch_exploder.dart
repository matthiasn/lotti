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
    var rejected = 0;
    final rejectedDetails = <String>[];
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

        // Fail-closed existence gate for labels. A label id is rejected when
        // (a) it is missing/blank, or (b) a wired resolver runs cleanly and
        // finds no such label — a hallucinated id the model invented. A
        // transient resolver *error* is NOT a rejection: we cannot prove the
        // id is fake, so the item is kept (the summary falls back to the id).
        // Rejecting instead of queuing avoids surfacing a raw id as a
        // suggestion. The resolved name is reused for the summary below.
        String? resolvedLabelName;
        if (isLabelBatch) {
          final labelId = element['id'];
          if (labelId is! String || labelId.isEmpty) {
            rejected++;
            rejectedDetails.add('label assignment is missing a string "id"');
            continue;
          }
          if (labelNameResolver != null) {
            final resolution = await _resolveLabelNameChecked(labelId);
            if (!resolution.errored && resolution.name == null) {
              rejected++;
              rejectedDetails.add(
                'label "$labelId" does not exist — only use label ids from '
                'the "Available Labels" section; do not invent ids',
              );
              continue;
            }
            resolvedLabelName = resolution.name;
          }
        }

        // Resolve state once per item to avoid redundant DB lookups and
        // duplicate error logging. `errored` distinguishes a transient
        // resolver failure (keep conservatively) from a clean not-found
        // (reject as a hallucinated id) below.
        final itemId = element['id'];
        var resolveErrored = false;
        ({String? title, bool? isChecked, bool? isArchived})? resolvedState;
        if (itemId is String && !isLabelBatch) {
          final resolution = await _resolveStateChecked(itemId);
          resolveErrored = resolution.errored;
          resolvedState = resolution.state;
        }

        // Fail-closed existence gate for updates/migrations that reference an
        // existing checklist item by id. A missing id, or a wired resolver
        // that runs cleanly and finds nothing, is rejected — queuing it would
        // render as a raw id and could not be applied. A transient resolver
        // error keeps the item (we cannot prove the id is fake).
        // `add_checklist_item` carries no id and is exempt.
        final referencesExistingItem =
            singularToolName == TaskAgentToolNames.updateChecklistItem ||
            singularToolName == TaskAgentToolNames.migrateChecklistItem;
        if (referencesExistingItem) {
          if (itemId is! String || itemId.isEmpty) {
            rejected++;
            rejectedDetails.add(
              '$singularToolName is missing a checklist item "id"',
            );
            continue;
          }
          if (checklistItemStateResolver != null &&
              !resolveErrored &&
              resolvedState == null) {
            rejected++;
            rejectedDetails.add(
              'checklist item "$itemId" does not exist — only reference ids '
              'present in the task context; do not invent ids',
            );
            continue;
          }
        }

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
            ? _generateLabelSummary(element, resolvedName: resolvedLabelName)
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
      rejected: rejected,
      rejectedDetails: rejectedDetails,
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

  /// Resolve a checklist item's current state via the injected resolver,
  /// distinguishing a clean not-found from a transient resolver failure.
  ///
  /// - `errored: false, state: <value>` — resolver ran and found the item.
  /// - `errored: false, state: null` — resolver ran and found nothing (the id
  ///   does not exist), or no resolver is wired.
  /// - `errored: true, state: null` — the resolver threw; the caller must keep
  ///   the item conservatively rather than treat the id as fake.
  Future<
    ({
      bool errored,
      ({String? title, bool? isChecked, bool? isArchived})? state,
    })
  >
  _resolveStateChecked(String itemId) async {
    final resolver = checklistItemStateResolver;
    if (resolver == null) return (errored: false, state: null);
    try {
      return (errored: false, state: await resolver(itemId));
    } catch (e, s) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'failed to resolve checklist item state for '
            '${DomainLogger.sanitizeId(itemId)}',
        stackTrace: s,
      );
      return (errored: true, state: null);
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
  ///
  /// [resolvedName] is the label name resolved by the caller's existence gate.
  /// It is null only on the no-resolver path or after a transient resolver
  /// error, where the raw-id fallback is the best available display. The name
  /// is never re-resolved here, so a clean not-found never reaches this method
  /// (it was already rejected by the gate).
  String _generateLabelSummary(
    Map<String, dynamic> args, {
    String? resolvedName,
  }) {
    final labelId = args['id'];
    final confidence = args['confidence'];
    final display =
        resolvedName ?? (labelId is String ? _truncateId(labelId) : '?');
    final confidenceSuffix =
        confidence is String &&
            const ['very_high', 'high', 'medium', 'low'].contains(confidence)
        ? ' ($confidence)'
        : '';
    return 'Assign label: "$display"$confidenceSuffix';
  }

  /// Resolve a label's human-readable name via the injected resolver. Returns
  /// null on a miss or a transient error; callers that must tell those apart
  /// use [_resolveLabelNameChecked].
  Future<String?> _resolveLabelName(String labelId) async =>
      (await _resolveLabelNameChecked(labelId)).name;

  /// Resolve a label name, distinguishing a clean not-found
  /// (`errored: false, name: null`) from a transient resolver failure
  /// (`errored: true`). See [_resolveStateChecked] for the same contract.
  Future<({bool errored, String? name})> _resolveLabelNameChecked(
    String labelId,
  ) async {
    final resolver = labelNameResolver;
    if (resolver == null) return (errored: false, name: null);
    try {
      return (errored: false, name: await resolver(labelId));
    } catch (e, s) {
      domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message:
            'failed to resolve label name for '
            '${DomainLogger.sanitizeId(labelId)}',
        stackTrace: s,
      );
      return (errored: true, name: null);
    }
  }

  /// Truncate a UUID to a short prefix for display as a fallback.
  static String _truncateId(String id) =>
      id.length > 8 ? '${id.substring(0, 8)}…' : id;
}

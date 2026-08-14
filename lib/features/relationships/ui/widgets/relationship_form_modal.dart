import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Upper bound on the form's height as a fraction of the viewport — the
/// create-modal sizing shared with `ProjectCreateForm`.
const double _modalMaxHeightFraction = 0.9;

/// Cadence presets offered in the form (plan v2 D1: presets over a free
/// integer field). `null` means no cadence.
const List<int?> relationshipCadencePresets = [null, 7, 14, 30, 90];

/// The localized label for a check-in cadence — shared by the form and the
/// detail page. Values outside the presets (possible via sync, since the
/// data model keeps a free integer) get an honest "every N days" label
/// instead of being lumped into the nearest preset.
String relationshipCadenceLabel(BuildContext context, int? days) =>
    switch (days) {
      null => context.messages.relationshipCadenceNone,
      7 => context.messages.relationshipCadenceWeekly,
      14 => context.messages.relationshipCadenceFortnightly,
      30 => context.messages.relationshipCadenceMonthly,
      90 => context.messages.relationshipCadenceQuarterly,
      final other => context.messages.relationshipCadenceEveryNDays(other),
    };

/// The localized label for a relationship status — shared by the form's
/// status picker and the detail page's status chip.
String relationshipStatusLabel(
  BuildContext context,
  RelationshipStatus status,
) => switch (status) {
  RelationshipActive() => context.messages.relationshipStatusActive,
  RelationshipDormant() => context.messages.relationshipStatusDormant,
  RelationshipArchived() => context.messages.relationshipStatusArchived,
};

/// Opens the responsive add-person overlay. Resolves to the created
/// [RelationshipEntry], or `null` when dismissed.
Future<RelationshipEntry?> showRelationshipCreateModal({
  required BuildContext context,
}) {
  return ModalUtils.showSinglePageModal<RelationshipEntry>(
    context: context,
    title: context.messages.relationshipCreateTitle,
    builder: (modalContext) => const RelationshipForm(),
  );
}

/// Opens the edit overlay prefilled from [relationship]. Resolves to the
/// updated [RelationshipEntry], or `null` when dismissed.
Future<RelationshipEntry?> showRelationshipEditModal({
  required BuildContext context,
  required RelationshipEntry relationship,
}) {
  return ModalUtils.showSinglePageModal<RelationshipEntry>(
    context: context,
    title: context.messages.relationshipEditTitle,
    builder: (modalContext) => RelationshipForm(initial: relationship),
  );
}

/// The status kinds the form's picker can select between; the concrete
/// [RelationshipStatus] instance (id, createdAt) is only minted on save,
/// and only when the kind actually changed.
enum _StatusKind { active, dormant, archived }

_StatusKind _kindOf(RelationshipStatus status) => switch (status) {
  RelationshipActive() => _StatusKind.active,
  RelationshipDormant() => _StatusKind.dormant,
  RelationshipArchived() => _StatusKind.archived,
};

/// The add/edit person form rendered inside [showRelationshipCreateModal]
/// and [showRelationshipEditModal]: name, optional nickname, the `important`
/// consent switch, a cadence preset, and (in edit mode) the status. Persists
/// through [RelationshipRepository]; pops with the saved entry on success.
class RelationshipForm extends ConsumerStatefulWidget {
  const RelationshipForm({this.initial, super.key});

  /// When set, the form edits this relationship instead of creating one.
  final RelationshipEntry? initial;

  @override
  ConsumerState<RelationshipForm> createState() => _RelationshipFormState();
}

class _RelationshipFormState extends ConsumerState<RelationshipForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _nicknameController;
  late bool _important;
  late int? _cadenceDays;
  late _StatusKind _statusKind;
  bool _isSaving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initial?.data;
    _nameController = TextEditingController(text: data?.title ?? '');
    _nicknameController = TextEditingController(text: data?.nickname ?? '');
    _important = data?.important ?? false;
    _cadenceDays = data?.checkInCadenceDays;
    _statusKind = data != null ? _kindOf(data.status) : _StatusKind.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  RelationshipStatus _mintStatus(_StatusKind kind) {
    final now = DateTime.now();
    final id = uuid.v1();
    final utcOffset = now.timeZoneOffset.inMinutes;
    return switch (kind) {
      _StatusKind.active => RelationshipStatus.active(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
      ),
      _StatusKind.dormant => RelationshipStatus.dormant(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
      ),
      _StatusKind.archived => RelationshipStatus.archived(
        id: id,
        createdAt: now,
        utcOffset: utcOffset,
      ),
    };
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.relationshipNameRequired,
      );
      return;
    }

    setState(() => _isSaving = true);
    final repository = ref.read(relationshipRepositoryProvider);
    final nickname = _nicknameController.text.trim();

    try {
      if (_isEditing) {
        final initial = widget.initial!;
        var data = initial.data.copyWith(
          title: name,
          nickname: nickname.isEmpty ? null : nickname,
          important: _important,
          checkInCadenceDays: _cadenceDays,
        );
        // Append the replaced status to history when the kind changed — the
        // ProjectDetailController precedent.
        if (_statusKind != _kindOf(initial.data.status)) {
          data = data.copyWith(
            status: _mintStatus(_statusKind),
            statusHistory: [...data.statusHistory, initial.data.status],
          );
        }
        final updated = initial.copyWith(data: data);
        final success = await repository.updateRelationship(updated);
        if (!mounted) return;
        if (success) {
          Navigator.of(context).pop(updated);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.relationshipErrorUpdateFailed,
          );
        }
      } else {
        final created = await repository.createRelationship(
          data: RelationshipData(
            title: name,
            nickname: nickname.isEmpty ? null : nickname,
            important: _important,
            checkInCadenceDays: _cadenceDays,
            status: _mintStatus(_StatusKind.active),
          ),
        );
        if (!mounted) return;
        if (created != null) {
          Navigator.of(context).pop(created);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.relationshipErrorCreateFailed,
          );
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to save relationship',
        name: 'RelationshipForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: _isEditing
              ? context.messages.relationshipErrorUpdateFailed
              : context.messages.relationshipErrorCreateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    Widget sectionLabel(String text) => Text(
      text,
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _modalMaxHeightFraction,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LottiTextField(
                    controller: _nameController,
                    labelText: messages.relationshipNameLabel,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.words,
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  LottiTextField(
                    controller: _nicknameController,
                    labelText: messages.relationshipNicknameLabel,
                    textCapitalization: TextCapitalization.words,
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _important,
                    onChanged: (value) => setState(() => _important = value),
                    title: Text(
                      messages.relationshipImportantLabel,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    subtitle: Text(
                      messages.relationshipImportantDescription,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  sectionLabel(messages.relationshipCadenceLabel),
                  SizedBox(height: tokens.spacing.step3),
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step3,
                    children: [
                      for (final preset in relationshipCadencePresets)
                        ChoiceChip(
                          label: Text(
                            relationshipCadenceLabel(context, preset),
                          ),
                          selected: _cadenceDays == preset,
                          onSelected: (_) =>
                              setState(() => _cadenceDays = preset),
                        ),
                    ],
                  ),
                  if (_isEditing) ...[
                    SizedBox(height: tokens.spacing.step5),
                    sectionLabel(messages.relationshipStatusFieldLabel),
                    SizedBox(height: tokens.spacing.step3),
                    Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step3,
                      children: [
                        for (final kind in _StatusKind.values)
                          ChoiceChip(
                            label: Text(_statusKindLabel(context, kind)),
                            selected: _statusKind == kind,
                            onSelected: (_) =>
                                setState(() => _statusKind = kind),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DesignSystemButton(
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: tokens.spacing.step4),
              DesignSystemButton(
                label: _isEditing ? messages.saveButton : messages.createButton,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusKindLabel(BuildContext context, _StatusKind kind) =>
    switch (kind) {
      _StatusKind.active => context.messages.relationshipStatusActive,
      _StatusKind.dormant => context.messages.relationshipStatusDormant,
      _StatusKind.archived => context.messages.relationshipStatusArchived,
    };

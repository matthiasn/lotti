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

/// Cadence presets offered on creation (plan v2 D1: presets over a free
/// integer field). `null` means no cadence.
const List<int?> relationshipCadencePresets = [null, 7, 14, 30, 90];

/// Opens the responsive add-person overlay. Resolves to the created
/// [RelationshipEntry], or `null` when dismissed.
Future<RelationshipEntry?> showRelationshipCreateModal({
  required BuildContext context,
}) {
  return ModalUtils.showSinglePageModal<RelationshipEntry>(
    context: context,
    title: context.messages.relationshipCreateTitle,
    builder: (modalContext) => const RelationshipCreateForm(),
  );
}

/// The add-person form rendered inside [showRelationshipCreateModal]:
/// name, optional nickname, the `important` consent switch, and a cadence
/// preset. Persists through [RelationshipRepository]; pops with the created
/// entry on success.
class RelationshipCreateForm extends ConsumerStatefulWidget {
  const RelationshipCreateForm({super.key});

  @override
  ConsumerState<RelationshipCreateForm> createState() =>
      _RelationshipCreateFormState();
}

class _RelationshipCreateFormState
    extends ConsumerState<RelationshipCreateForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _nicknameController;
  bool _important = false;
  int? _cadenceDays;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  String _cadenceLabel(BuildContext context, int? days) => switch (days) {
    null => context.messages.relationshipCadenceNone,
    7 => context.messages.relationshipCadenceWeekly,
    14 => context.messages.relationshipCadenceFortnightly,
    30 => context.messages.relationshipCadenceMonthly,
    _ => context.messages.relationshipCadenceQuarterly,
  };

  Future<void> _handleCreate() async {
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
      final now = DateTime.now();
      final created = await repository.createRelationship(
        data: RelationshipData(
          title: name,
          nickname: nickname.isEmpty ? null : nickname,
          important: _important,
          checkInCadenceDays: _cadenceDays,
          status: RelationshipStatus.active(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
        ),
      );

      if (created != null) {
        if (mounted) {
          Navigator.of(context).pop(created);
        }
      } else if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorCreateFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to create relationship',
        name: 'RelationshipCreateForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorCreateFailed,
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
                    autofocus: true,
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
                  Text(
                    messages.relationshipCadenceLabel,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step3,
                    children: [
                      for (final preset in relationshipCadencePresets)
                        ChoiceChip(
                          label: Text(_cadenceLabel(context, preset)),
                          selected: _cadenceDays == preset,
                          onSelected: (_) =>
                              setState(() => _cadenceDays = preset),
                        ),
                    ],
                  ),
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
                label: messages.createButton,
                onPressed: _isSaving ? null : _handleCreate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

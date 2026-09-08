import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_card.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_surfaces.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

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

/// The localized label for a contact channel type — shared by the form's
/// channel editor and the detail page's channel list.
String contactChannelTypeLabel(BuildContext context, ContactChannelType type) =>
    switch (type) {
      ContactChannelType.phone => context.messages.contactChannelTypePhone,
      ContactChannelType.mobile => context.messages.contactChannelTypeMobile,
      ContactChannelType.email => context.messages.contactChannelTypeEmail,
      ContactChannelType.messaging =>
        context.messages.contactChannelTypeMessaging,
    };

/// The icon for a contact channel type — shared with the detail page.
IconData contactChannelTypeIcon(ContactChannelType type) => switch (type) {
  ContactChannelType.phone => LottiIcons.call,
  ContactChannelType.mobile => LottiIcons.phone,
  ContactChannelType.email => LottiIcons.mail,
  ContactChannelType.messaging => LottiIcons.chat,
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

/// What the modal's pinned action bar needs from the form inside it: the
/// save intent and whether it is currently allowed. The form publishes after
/// every state change; the bar listens. Delete is not here — a person is
/// deleted from the page's kebab, never from inside their own edit sheet.
class RelationshipFormHandle extends ChangeNotifier {
  Future<void> Function()? _save;
  bool _canSave = false;
  bool _isEditing = false;

  bool get canSave => _canSave;

  /// Whether the sheet is editing an existing person, which decides the
  /// primary action's label (*Save* versus *Create*).
  bool get isEditing => _isEditing;

  Future<void> save() => _save?.call() ?? Future.value();

  void publish({
    required Future<void> Function()? save,
    required bool canSave,
    required bool isEditing,
  }) {
    _save = save;
    _canSave = canSave;
    _isEditing = isEditing;
    notifyListeners();
  }
}

/// Room under the form for the pinned action bar, so the last field can
/// scroll clear of it (the check-in sheet's measurement).
EdgeInsets _formPadding(BuildContext context) {
  final tokens = context.designTokens;
  return EdgeInsets.fromLTRB(
    tokens.spacing.step5,
    tokens.spacing.step4,
    tokens.spacing.step5,
    tokens.spacing.step11 + tokens.spacing.step6,
  );
}

/// Opens the responsive add-person overlay. Resolves to the created
/// [RelationshipEntry], or `null` when dismissed.
Future<RelationshipEntry?> showRelationshipCreateModal({
  required BuildContext context,
}) {
  final handle = RelationshipFormHandle();
  return ModalUtils.showSinglePageModal<RelationshipEntry>(
    context: context,
    title: context.messages.relationshipCreateTitle,
    padding: _formPadding(context),
    stickyActionBarBuilder: (_) => RelationshipFormStickyActions(
      handle: handle,
    ),
    builder: (modalContext) => RelationshipForm(handle: handle),
  );
}

/// Opens the edit overlay prefilled from [relationship]. Resolves to the
/// updated [RelationshipEntry], or `null` when dismissed.
Future<RelationshipEntry?> showRelationshipEditModal({
  required BuildContext context,
  required RelationshipEntry relationship,
}) {
  final handle = RelationshipFormHandle();
  return ModalUtils.showSinglePageModal<RelationshipEntry>(
    context: context,
    title: context.messages.relationshipEditTitle,
    padding: _formPadding(context),
    stickyActionBarBuilder: (_) => RelationshipFormStickyActions(
      handle: handle,
    ),
    builder: (modalContext) => RelationshipForm(
      initial: relationship,
      handle: handle,
    ),
  );
}

/// The modal's pinned actions: *Save* reachable without scrolling past three
/// cards of fields, Cancel beside it. Reads the form through its [handle].
class RelationshipFormStickyActions extends StatelessWidget {
  const RelationshipFormStickyActions({required this.handle, super.key});

  final RelationshipFormHandle handle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return ListenableBuilder(
      listenable: handle,
      builder: (context, _) => DesignSystemModalActionBar(
        glass: true,
        padding: EdgeInsets.all(tokens.spacing.step5),
        secondary: [
          DesignSystemButton(
            key: const ValueKey('person-form-cancel'),
            label: messages.cancelButton,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        primary: DesignSystemButton(
          key: const ValueKey('person-form-save'),
          label: handle.isEditing ? messages.saveButton : messages.createButton,
          fullWidth: true,
          onPressed: handle.canSave ? handle.save : null,
        ),
      ),
    );
  }
}

/// One editable contact-channel row: the picked type plus live controllers
/// for value and optional label. Rows with an empty value are dropped on
/// save, so an added-then-abandoned row never persists.
class _ChannelDraft {
  _ChannelDraft()
    : type = ContactChannelType.mobile,
      valueController = TextEditingController(),
      labelController = TextEditingController();

  _ChannelDraft.fromChannel(ContactChannel channel)
    : type = channel.type,
      valueController = TextEditingController(text: channel.value),
      labelController = TextEditingController(text: channel.label ?? '');

  ContactChannelType type;
  final TextEditingController valueController;
  final TextEditingController labelController;

  ContactChannel? toChannel() {
    final value = valueController.text.trim();
    if (value.isEmpty) return null;
    final label = labelController.text.trim();
    return ContactChannel(
      type: type,
      value: value,
      label: label.isEmpty ? null : label,
    );
  }

  void dispose() {
    valueController.dispose();
    labelController.dispose();
  }
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
/// and [showRelationshipEditModal].
///
/// Three cards, in the design's order (2026-09-06 §6): **Who** (name,
/// nickname, category as a colour dot), **Important** (the consent switch,
/// what it turns on, and — only once it is on — the cadence presets), and
/// **How to reach them** (the channel editor under its privacy line). The
/// status picker joins the first card while editing. Persists through
/// [RelationshipRepository]; pops with the saved entry on success.
///
/// The form has no inline action row: it publishes save and can-save to its
/// [handle], and [RelationshipFormStickyActions] renders them in the modal's
/// pinned bar, so Save stays reachable without scrolling three cards.
class RelationshipForm extends ConsumerStatefulWidget {
  const RelationshipForm({required this.handle, this.initial, super.key});

  /// The channel through which the pinned action bar reads this form.
  final RelationshipFormHandle handle;

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
  String? _categoryId;
  final List<_ChannelDraft> _channels = [];
  bool _isSaving = false;

  bool get _isEditing => widget.initial != null;

  /// The person as last read. Starts as [RelationshipForm.initial] and is
  /// re-read after every write the Photo card makes, because those land
  /// *before* Save: a Save built from the entry the form opened with would
  /// write the old photo back over the new one.
  RelationshipEntry? _person;

  @override
  void initState() {
    super.initState();
    final data = widget.initial?.data;
    _nameController = TextEditingController(text: data?.title ?? '');
    _nicknameController = TextEditingController(text: data?.nickname ?? '');
    _important = data?.important ?? false;
    _cadenceDays = data?.checkInCadenceDays;
    _statusKind = data != null ? _kindOf(data.status) : _StatusKind.active;
    _categoryId = widget.initial?.meta.categoryId;
    _person = widget.initial;
    _channels.addAll(
      (data?.contactChannels ?? const []).map(_ChannelDraft.fromChannel),
    );
  }

  @override
  void didUpdateWidget(RelationshipForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A host that re-supplies the form with a different person — or a person
    // where there was none — is handing over a persisted entry, which is what
    // `_person` tracks. The same person re-supplied is not adopted: the
    // re-read after a Photo card write is at least as fresh as the host's
    // opening snapshot.
    final initial = widget.initial;
    if (initial != null && initial.id != _person?.id) {
      _person = initial;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    for (final channel in _channels) {
      channel.dispose();
    }
    super.dispose();
  }

  /// Non-empty channel rows in their edited order (ADR 0041 §2: manual
  /// entry on every platform).
  List<ContactChannel> get _editedChannels =>
      _channels.map((draft) => draft.toChannel()).nonNulls.toList();

  RelationshipStatus _mintStatus(_StatusKind kind) {
    final now = clock.now();
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

  /// Re-reads the person after the Photo card wrote, so Save and the card
  /// itself work from what is persisted rather than from the form's opening
  /// snapshot.
  Future<void> _reloadPerson() async {
    final id = _person?.id;
    if (id == null) return;
    final fresh = await ref
        .read(relationshipRepositoryProvider)
        .getRelationshipById(id);
    if (mounted && fresh != null) setState(() => _person = fresh);
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
    // Every provider is read before the first `await`. Saving pops the sheet,
    // and the category write, the agent hand-off and any retry that follows
    // all run past that point — reading through `ref` once the element is
    // unmounted throws and aborts the save mid-way.
    final repository = ref.read(relationshipRepositoryProvider);
    final journalRepository = ref.read(journalRepositoryProvider);
    // Only resolved when it will actually be used — `_important` is form
    // state, known before any await, so this stays ahead of the unmount.
    final agentService = _important
        ? ref.read(relationshipAgentServiceProvider)
        : null;
    final nickname = _nicknameController.text.trim();

    try {
      if (_isEditing) {
        final initial = _person!;
        var data = initial.data.copyWith(
          title: name,
          nickname: nickname.isEmpty ? null : nickname,
          important: _important,
          checkInCadenceDays: _cadenceDays,
          contactChannels: _editedChannels,
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
        final saved = await repository.updateRelationship(updated);
        // Category lives on the metadata, not the payload: route the change
        // through the dedicated journal path, which handles clearing (a
        // freezed copyWith cannot null a field) plus vector clock and sync.
        // Its result is part of the save's verdict: a swallowed category
        // write would otherwise pop the modal on a half-saved person, and
        // the user would see the old category with nothing to retry.
        var success = saved;
        if (saved && _categoryId != initial.meta.categoryId) {
          success = await journalRepository.updateCategoryId(
            initial.meta.id,
            categoryId: _categoryId,
          );
        }
        // Keyed on the payload write, not the verdict: `important` and the
        // cadence are already persisted, so the agent must be wired even
        // when the category leg failed.
        if (saved) _ensureAgentIfImportant(agentService, updated);
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
            contactChannels: _editedChannels,
            status: _mintStatus(_StatusKind.active),
          ),
          categoryId: _categoryId,
        );
        if (created != null) _ensureAgentIfImportant(agentService, created);
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

  /// The lazy-create trigger (ADR 0059 Decision 2): marking a person
  /// important is what mints their agent; an existing agent makes this an
  /// idempotent re-subscribe plus one €0 re-evaluation (so a cadence edit
  /// takes effect immediately). Fire-and-forget with contained failure —
  /// agent wiring must never fail the save the user just watched succeed.
  /// Takes the service rather than reading it: this outlives the sheet by
  /// design — the agent is created after the modal has popped — so it must
  /// not touch `ref`.
  void _ensureAgentIfImportant(
    RelationshipAgentService? agentService,
    RelationshipEntry relationship,
  ) {
    if (!relationship.data.important || agentService == null) return;
    unawaited(() async {
      try {
        await agentService.ensureAgentForRelationship(relationship);
      } catch (e, s) {
        developer.log(
          'Failed to ensure relationship agent',
          name: 'RelationshipForm',
          error: e,
          stackTrace: s,
        );
      }
    }());
  }

  /// Republishes the pinned bar's view of this form. Deferred to the end of
  /// the frame because the bar lives in the modal's sticky slot — a sibling
  /// subtree — and notifying a listener that is mid-build throws.
  void _publish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.handle.publish(
        save: _handleSave,
        canSave: !_isSaving,
        isEditing: _isEditing,
      );
    });
  }

  /// Folds a picked address-book entry's channels into the drafts, skipping
  /// values the form already holds.
  ///
  /// Nothing is written here: the picked channels become editable rows like
  /// any other, and the person is saved only when the user says so. That is
  /// what separates this from the detail page's *Link contact*, which
  /// persists — a form that saved behind its own Save button would lose the
  /// edits still sitting in its fields.
  Future<void> _addFromContacts() async {
    final service = ref.read(contactsServiceProvider);
    if (!service.isSupported) return;
    final picked = await service.pickSingle();
    if (picked == null || !mounted) return;

    // Sameness is the model's own rule (type plus a normalized value), so a
    // typed `+1 (555) 010-9999` and the book's `+15550109999` are one channel,
    // and a phone and an email that happen to read alike are not.
    final existing = _editedChannels;
    final merged = mergeContactChannels(
      existing: existing,
      incoming: picked.channels,
    );
    final added = merged.skip(existing.length);
    if (added.isEmpty) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.warning,
          title: context.messages.relationshipContactNoChanges,
        );
      }
      return;
    }
    setState(() {
      _channels.addAll(added.map(_ChannelDraft.fromChannel));
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    // The bar mirrors this build's state; see `_publish`.
    _publish();

    Widget sectionLabel(String text) => Text(
      text,
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );

    Widget gap(double height) => SizedBox(height: height);

    // One scrollable, not two — see the same note on the check-in capture
    // sheet. The modal page already scrolls its child and stacks a top bar,
    // padding and the bottom safe area on top of it, so a form that also
    // capped itself at `modalMaxHeightFraction` of the SCREEN overflowed the
    // page, and the inner scroll view ate the drag that would have reached
    // the action row.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo — only for a person who already exists: its actions write
        // straight away, and there is nothing to write to before the first
        // Save. A new person gets their pictures from the page's avatar.
        if (_isEditing) ...[
          PersonPhotoCard(
            person: _person!,
            actions: productionPersonPhotoActions(
              ref,
              context: context,
              relationship: _person!,
            ),
            onChanged: _reloadPerson,
          ),
          gap(tokens.spacing.step4),
        ],
        // Who — identity, and the category as a colour dot rather than a
        // second large avatar competing with the person's own.
        DesignSystemSectionCard(
          key: const ValueKey('person-form-who-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PersonCardHeader(title: messages.relationshipFormWhoTitle),
              gap(tokens.spacing.step4),
              LottiTextField(
                controller: _nameController,
                labelText: messages.relationshipNameLabel,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
              ),
              gap(tokens.spacing.step4),
              LottiTextField(
                controller: _nicknameController,
                labelText: messages.relationshipNicknameLabel,
                textCapitalization: TextCapitalization.words,
              ),
              gap(tokens.spacing.step4),
              // Category scoping (the ProjectCreateForm precedent): the
              // relationship's category also seeds every check-in created
              // under it.
              PersonCategoryRow(
                categoryId: _categoryId,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
              if (_isEditing) ...[
                gap(tokens.spacing.step4),
                sectionLabel(messages.relationshipStatusFieldLabel),
                gap(tokens.spacing.step3),
                DsChoicePills<_StatusKind>(
                  value: _statusKind,
                  values: _StatusKind.values,
                  labelFor: (kind) => _statusKindLabel(context, kind),
                  onSelected: (kind) => setState(() => _statusKind = kind),
                ),
              ],
            ],
          ),
        ),
        gap(tokens.spacing.cardItemSpacing),
        // Important — the consent switch, what it turns on, and the cadence
        // it schedules. The cadence only exists for someone who is nurtured,
        // so it appears with the switch rather than beside it.
        DesignSystemSectionCard(
          key: const ValueKey('person-form-important-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One labelled control, not a label sitting near a switch: a
              // screen reader reads "Important" with the switch's state, and
              // the label itself toggles.
              MergeSemantics(
                child: InkWell(
                  onTap: () => setState(() => _important = !_important),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          messages.relationshipImportantLabel,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(color: tokens.colors.text.highEmphasis),
                        ),
                      ),
                      Switch(
                        value: _important,
                        onChanged: (value) =>
                            setState(() => _important = value),
                      ),
                    ],
                  ),
                ),
              ),
              gap(tokens.spacing.step1),
              // Follows the name field as it is typed, so the sentence names
              // the person the moment there is a person to name — without
              // rebuilding the rest of the form on every keystroke.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, _, _) => Text(
                  _importantBody(context),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              if (_important) ...[
                gap(tokens.spacing.step4),
                sectionLabel(messages.relationshipCadencePromptLabel),
                gap(tokens.spacing.step3),
                DsChoicePills<int?>(
                  value: _cadenceDays,
                  values: relationshipCadencePresets,
                  labelFor: (preset) => relationshipCadenceLabel(
                    context,
                    preset,
                  ),
                  onSelected: (preset) => setState(() => _cadenceDays = preset),
                ),
              ],
            ],
          ),
        ),
        gap(tokens.spacing.cardItemSpacing),
        // How to reach them — the channel editor under the privacy line the
        // page's Reach card carries, so the promise is repeated where the
        // numbers are actually typed.
        DesignSystemSectionCard(
          key: const ValueKey('person-form-reach-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PersonCardHeader(title: messages.relationshipFormReachTitle),
              gap(tokens.spacing.step1),
              Text(
                messages.relationshipReachPrivacy,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              gap(tokens.spacing.step3),
              for (final (index, draft) in _channels.indexed) ...[
                _ChannelEditorRow(
                  key: ObjectKey(draft),
                  draft: draft,
                  onTypeChanged: (type) => setState(() => draft.type = type),
                  onRemoved: () => setState(() {
                    _channels.removeAt(index).dispose();
                  }),
                ),
                gap(tokens.spacing.step4),
              ],
              _AddChannelActions(
                onAdd: () => setState(() => _channels.add(_ChannelDraft())),
                onFromContacts: ref.watch(contactsServiceProvider).isSupported
                    ? () => unawaited(_addFromContacts())
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The *Important* explainer, naming the person once they have a name.
  ///
  /// It says what the switch turns **on** and where check-in notes go, and
  /// never claims that leaving it off keeps the person out of AI entirely —
  /// a chat, an explicit briefing and a dictated check-in all reach a model
  /// for anyone (the correction made in PR #4185).
  String _importantBody(BuildContext context) {
    final messages = context.messages;
    final name = _nameController.text.trim();
    return name.isEmpty
        ? messages.relationshipFormImportantBody
        : messages.relationshipFormImportantBodyNamed(name);
  }
}

/// The category as one quiet row: its name beside a colour dot, opening the
/// shared picker on tap. The dot is the whole colour treatment — a second
/// large avatar would compete with the person's own (design 2026-09-06 §6).
///
/// Clearing happens through the picker's own no-category row rather than an
/// inline ×, so there is one way to change this field and one place that
/// knows what the choices are. [onChanged] reports the picked category's id,
/// or null for cleared.
class PersonCategoryRow extends StatelessWidget {
  const PersonCategoryRow({
    required this.categoryId,
    required this.onChanged,
    super.key,
  });

  final String? categoryId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);

    return InkWell(
      key: const ValueKey('person-form-category'),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      onTap: () async {
        final result = await showCategoryPicker(
          context: context,
          title: messages.habitCategoryLabel,
          currentCategoryId: categoryId,
        );
        // null = dismissed (no change); otherwise apply the pick or the
        // clear, which the picker reports as a category-less result.
        if (result == null) return;
        onChanged(result.categoryOrNull?.id);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messages.habitCategoryLabel,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    category?.name ?? messages.habitCategoryHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: category == null
                          ? tokens.colors.text.lowEmphasis
                          : tokens.colors.text.highEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            if (category != null) ...[
              SizedBox(width: tokens.spacing.step3),
              Container(
                key: const ValueKey('person-form-category-dot'),
                width: tokens.spacing.step3,
                height: tokens.spacing.step3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorFromCssHex(
                    category.color,
                    substitute: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// *Add channel · or from contacts* — the manual row on every platform
/// (ADR 0041 §2), and beside it the address book where there is one.
class _AddChannelActions extends StatelessWidget {
  const _AddChannelActions({required this.onAdd, this.onFromContacts});

  final VoidCallback onAdd;
  final VoidCallback? onFromContacts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            key: const ValueKey('person-form-add-channel'),
            onPressed: onAdd,
            icon: const Icon(LottiIcons.add),
            label: Text(messages.relationshipAddChannelButton),
          ),
          if (onFromContacts != null) ...[
            Text(
              '·',
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
            TextButton(
              key: const ValueKey('person-form-add-from-contacts'),
              onPressed: onFromContacts,
              child: Text(messages.relationshipAddChannelFromContacts),
            ),
          ],
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

/// One channel's editor: type dropdown with a remove action, then the value
/// and optional label fields. The keyboard follows the picked type.
class _ChannelEditorRow extends StatelessWidget {
  const _ChannelEditorRow({
    required this.draft,
    required this.onTypeChanged,
    required this.onRemoved,
    super.key,
  });

  final _ChannelDraft draft;
  final ValueChanged<ContactChannelType> onTypeChanged;
  final VoidCallback onRemoved;

  TextInputType get _keyboardType => switch (draft.type) {
    ContactChannelType.phone ||
    ContactChannelType.mobile => TextInputType.phone,
    ContactChannelType.email => TextInputType.emailAddress,
    ContactChannelType.messaging => TextInputType.text,
  };

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ContactChannelType>(
                initialValue: draft.type,
                items: [
                  for (final type in ContactChannelType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            contactChannelTypeIcon(type),
                            size: tokens.spacing.step4,
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                          SizedBox(width: tokens.spacing.step3),
                          Text(contactChannelTypeLabel(context, type)),
                        ],
                      ),
                    ),
                ],
                onChanged: (type) {
                  if (type != null) onTypeChanged(type);
                },
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            IconButton(
              tooltip: messages.deleteButton,
              onPressed: onRemoved,
              icon: const Icon(LottiIcons.removeCircled),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step3),
        LottiTextField(
          controller: draft.valueController,
          labelText: messages.contactChannelValueLabel,
          keyboardType: _keyboardType,
        ),
        SizedBox(height: tokens.spacing.step3),
        LottiTextField(
          controller: draft.labelController,
          labelText: messages.contactChannelLabelLabel,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

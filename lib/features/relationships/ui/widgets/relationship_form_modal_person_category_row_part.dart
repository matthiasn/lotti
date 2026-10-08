part of 'relationship_form_modal.dart';

/// How often a reminder can come, as offered wherever reminders are turned
/// on (plan v2 D1: presets over a free integer field).
///
/// There is no "none": reminders that are on always run on an interval —
/// the runtime substitutes [relationshipDefaultCadenceDays] for a missing
/// one — so offering "No cadence" showed a choice the app then overrode.
const List<int> relationshipCadencePresets = [7, 14, 30, 90];

/// The choices to offer when [shown] is the interval on screen: the
/// presets, plus [shown] in its place when it is not one of them.
///
/// The data model keeps a free integer, and a synced person can carry, say,
/// 45 days. Offering only the presets would show nothing selected while Save
/// stored 45 — the mismatch between the screen and the schedule these
/// controls exist to prevent — so the stored value is offered as it is,
/// labelled "Every 45 days", until the user picks a preset instead.
List<int> relationshipCadenceChoices(int shown) =>
    relationshipCadencePresets.contains(shown)
    ? relationshipCadencePresets
    : ([...relationshipCadencePresets, shown]..sort());

/// The localized label for a check-in cadence — shared by the form and the
/// detail page. Values outside the presets (possible via sync, since the
/// data model keeps a free integer) get an honest "every N days" label
/// instead of being lumped into the nearest preset.
String relationshipCadenceLabel(BuildContext context, int days) =>
    switch (days) {
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
  Future<void> Function()? _dismiss;
  bool _canSave = false;
  bool _isEditing = false;

  bool get canSave => _canSave;

  /// Whether the sheet is editing an existing person, which decides the
  /// primary action's label (*Save* versus *Create*).
  bool get isEditing => _isEditing;

  Future<void> save() => _save?.call() ?? Future.value();

  /// Leaves the form the way its own back gesture does: asking first when
  /// there is unsaved work. Cancel goes through here rather than popping the
  /// route itself, so every way out asks the same question.
  Future<void> dismiss() => _dismiss?.call() ?? Future.value();

  void publish({
    required Future<void> Function()? save,
    required Future<void> Function()? dismiss,
    required bool canSave,
    required bool isEditing,
  }) {
    // The form publishes from `build`, so this arrives on every keystroke.
    // Only the two values the bar renders are worth a rebuild for; the
    // callbacks are read when a button is actually pressed.
    final changed = canSave != _canSave || isEditing != _isEditing;
    _save = save;
    _dismiss = dismiss;
    _canSave = canSave;
    _isEditing = isEditing;
    if (changed) notifyListeners();
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
    // The generic close button pops the route itself, which bypasses the
    // form's PopScope and takes the typed person with it. The check-in
    // composer hides it for the same reason; Cancel is in the pinned bar.
    showCloseButton: false,
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
    // See the create sheet: a close button that pops directly cannot ask.
    showCloseButton: false,
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
            // Not a bare pop: the form asks before dropping typed work.
            onPressed: () => unawaited(handle.dismiss()),
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
/// nickname, the names that come up with them, category as a colour dot), **Important** (the consent switch,
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
            // The swatch leads the value, as a category's colour does on
            // every other row that names one; trailing, it sat where the
            // chevron belongs.
            if (category != null) ...[
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
              SizedBox(width: tokens.spacing.step3),
            ],
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
            // The chevron the context chips wear, and it ends the row:
            // without it the row read as a read-out between two fields,
            // not the selector it is.
            SizedBox(width: tokens.spacing.step3),
            Icon(
              LottiIcons.chevronDown,
              key: const ValueKey('person-form-category-chevron'),
              size: IconSizes.s,
              color: tokens.colors.text.lowEmphasis,
            ),
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
                            size: IconSizes.xs,
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Multi-select import from the OS address book (plan v2 phase 7 item 3,
/// ADR 0041 D5).
///
/// Two steps on purpose. Picking is a bulk action, but deciding who to be
/// nudged about is not — the review step is what keeps the import from
/// filling the People tab with dormant entities that would destroy the nudge
/// signal. Nothing is written until the last button.
class ContactImportPage extends ConsumerStatefulWidget {
  const ContactImportPage({super.key});

  @override
  ConsumerState<ContactImportPage> createState() => _ContactImportPageState();
}

class _ContactImportPageState extends ConsumerState<ContactImportPage> {
  final _searchController = TextEditingController();
  bool _reviewing = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    // The permission prompt is part of opening this screen — the user asked
    // for the picker, which is the only moment access is requested
    // (ADR 0041 D5).
    //
    // Deferred past this frame because `load` writes to the provider before
    // its first await (the unsupported branch answers synchronously), and
    // Riverpod rejects a provider write while the tree is building. The
    // first frame therefore renders the idle spinner, which is what it would
    // have shown anyway.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(contactImportControllerProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);

    final controller = ref.read(contactImportControllerProvider.notifier);
    final created = await controller.importSelected();

    if (!mounted) return;
    setState(() => _importing = false);

    if (created.isEmpty) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.relationshipImportFailed,
      );
      return;
    }

    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.relationshipImportAdded(created.length),
    );
    Navigator.of(context).pop(created.length);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactImportControllerProvider);
    final messages = context.messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _reviewing
              ? messages.relationshipImportReviewTitle
              : messages.relationshipImportTitle,
        ),
        leading: _reviewing
            ? IconButton(
                icon: const Icon(LottiIcons.back),
                // Back from review returns to the selection with the choices
                // intact, rather than dropping them.
                onPressed: () => setState(() => _reviewing = false),
              )
            : null,
      ),
      body: SafeArea(
        child: switch (state.status) {
          ContactImportStatus.idle ||
          ContactImportStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          ContactImportStatus.denied => _Message(
            body: messages.relationshipImportPermissionBody,
            actionLabel: messages.relationshipImportGrantButton,
            onAction: () => unawaited(
              ref.read(contactImportControllerProvider.notifier).load(),
            ),
          ),
          ContactImportStatus.permanentlyDenied => _Message(
            body: messages.relationshipImportSettingsBody,
            actionLabel: messages.relationshipImportOpenSettings,
            onAction: () => unawaited(
              ref.read(contactsServiceProvider).openSystemSettings(),
            ),
            secondaryLabel: messages.relationshipImportRetry,
            onSecondary: () => unawaited(
              ref.read(contactImportControllerProvider.notifier).load(),
            ),
          ),
          ContactImportStatus.unsupported => _Message(
            body: messages.relationshipImportUnsupported,
          ),
          ContactImportStatus.empty => _Message(
            body: messages.relationshipImportEmpty,
          ),
          ContactImportStatus.ready =>
            _reviewing
                ? _ReviewStep(importing: _importing, onImport: _import)
                : _SelectStep(searchController: _searchController),
        },
      ),
      bottomNavigationBar: state.status != ContactImportStatus.ready
          ? null
          : _BottomBar(
              reviewing: _reviewing,
              importing: _importing,
              selectedCount: state.drafts.length,
              onReview: () => setState(() => _reviewing = true),
              onImport: _import,
            ),
    );
  }
}

/// The search field plus the checkbox list.
class _SelectStep extends ConsumerWidget {
  const _SelectStep({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final controller = ref.watch(contactImportControllerProvider.notifier);
    // Watched so the list rebuilds as the query and the selection change.
    ref.watch(contactImportControllerProvider);
    final visible = controller.visibleContacts;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(tokens.spacing.step5),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: context.messages.relationshipImportSearchHint,
              prefixIcon: const Icon(LottiIcons.search),
            ),
            onChanged: controller.setQuery,
          ),
        ),
        if (visible.isEmpty)
          Expanded(
            child: _Message(body: context.messages.relationshipImportNoMatches),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final contact = visible[index];
                return CheckboxListTile(
                  value: controller.isSelected(contact.id),
                  onChanged: (_) => controller.toggleSelection(contact),
                  title: Text(contact.displayName),
                  subtitle: contact.channels.isEmpty
                      ? null
                      : Text(
                          contact.channels.map((c) => c.value).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// One row per chosen contact, with the two decisions the import needs.
class _ReviewStep extends ConsumerWidget {
  const _ReviewStep({required this.importing, required this.onImport});

  final bool importing;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final state = ref.watch(contactImportControllerProvider);
    final controller = ref.read(contactImportControllerProvider.notifier);
    final drafts = state.drafts.values.toList();

    return ListView.builder(
      padding: EdgeInsets.all(tokens.spacing.step5),
      itemCount: drafts.length,
      itemBuilder: (context, index) {
        final draft = drafts[index];
        return Card(
          margin: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.contact.displayName,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                if (draft.contact.channels.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    draft.contact.channels.map((c) => c.value).join(' · '),
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: draft.important,
                  title: Text(context.messages.relationshipImportantLabel),
                  subtitle: Text(
                    context.messages.relationshipImportantDescription,
                  ),
                  onChanged: (value) => controller.setImportant(
                    contactId: draft.contact.id,
                    important: value,
                  ),
                ),
                // The cadence only exists for people who are nurtured, so it
                // appears only once importance is on.
                if (draft.important)
                  Wrap(
                    spacing: tokens.spacing.step3,
                    children: [
                      for (final preset in relationshipCadencePresets)
                        ChoiceChip(
                          label: Text(
                            relationshipCadenceLabel(context, preset),
                          ),
                          selected: draft.cadenceDays == preset,
                          onSelected: (_) => controller.setCadence(
                            contactId: draft.contact.id,
                            cadenceDays: preset,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.reviewing,
    required this.importing,
    required this.selectedCount,
    required this.onReview,
    required this.onImport,
  });

  final bool reviewing;
  final bool importing;
  final int selectedCount;
  final VoidCallback onReview;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Nothing chosen yet: no bar rather than a disabled button taking up the
    // bottom of a list the user is still scrolling.
    if (selectedCount == 0) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        // The Column is load-bearing, not decoration. A `fullWidth` button
        // centres its content without a height factor, so under the loose
        // constraints Scaffold hands a bottomNavigationBar it grows to fill
        // them — silently, with no overflow warning — and the list above it
        // collapses to nothing. A vertical Flex passes *unbounded* main-axis
        // constraints to its children (a Row's cross-axis constraints are
        // merely loose, which is not enough), and under an unbounded height
        // the same Center shrink-wraps to the button. `stretch` then keeps
        // the full width.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesignSystemButton(
              label: reviewing
                  ? messages.relationshipImportConfirmButton(selectedCount)
                  : messages.relationshipImportReviewButton(selectedCount),
              fullWidth: true,
              isLoading: importing,
              onPressed: reviewing ? () => unawaited(onImport()) : onReview,
            ),
          ],
        ),
      ),
    );
  }
}

/// A centered explanation with up to two actions — the shape every
/// non-listing state of this screen takes.
class _Message extends StatelessWidget {
  const _Message({
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              body,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            if (actionLabel != null) ...[
              SizedBox(height: tokens.spacing.sectionGap),
              DesignSystemButton(label: actionLabel!, onPressed: onAction),
            ],
            if (secondaryLabel != null) ...[
              SizedBox(height: tokens.spacing.step3),
              DesignSystemButton(
                label: secondaryLabel!,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

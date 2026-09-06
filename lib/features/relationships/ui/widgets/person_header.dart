import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_link_action.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:material_ui/material_ui.dart';

/// The person page's cover-style hero (design 2026-09-06 §2–3): a teal wash
/// with no imagery, carrying back · Talk to agent · edit · kebab, with the
/// persona avatar overlapping its lower edge. Pinned, so the actions stay
/// reachable while the page scrolls; once the wash band has folded away
/// the bar names the person the hero itself leaves to the header block.
///
/// A persistent header of its own rather than a `SliverAppBar`: the avatar
/// hangs below the header's extent, over the block that follows, and every
/// layer of an app bar (its stack, its flexible space) clips that overflow.
/// Slivers paint back to front, so the header — earlier in the list —
/// paints its overhanging avatar over the content scrolling under it.
class PersonHeroAppBar extends StatelessWidget {
  const PersonHeroAppBar({
    required this.relationship,
    required this.onBack,
    required this.onTalkToAgent,
    required this.onDelete,
    this.contentInset = 0,
    super.key,
  });

  final RelationshipEntry relationship;
  final VoidCallback onBack;
  final VoidCallback onTalkToAgent;
  final Future<void> Function() onDelete;

  /// The page's horizontal content inset, so the avatar lines up with the
  /// header block's left edge — the gutter on a phone, the centred column's
  /// edge on a desktop window.
  final double contentInset;

  /// The wash band's extent below the toolbar: the avatar overlaps its lower
  /// edge by half its diameter, so the band has to be tall enough to read
  /// as a band rather than a stripe.
  static double bandExtent(DsTokens tokens) => tokens.spacing.step12;

  /// The avatar diameter; half of it hangs below the hero.
  static double avatarSize(DsTokens tokens) => tokens.spacing.step11;

  /// The wash itself: the interactive accent at the tint alpha over the page
  /// surface — the same recipe every tone-tinted card fill uses.
  static Color washColor(DsTokens tokens) => Color.alphaBlend(
    tokens.colors.interactive.enabled.withValues(alpha: SurfaceAlphas.tint),
    tokens.colors.background.level01,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final desktop = isDesktopLayout(context);
    final ink = tokens.colors.text.highEmphasis;
    // On the desktop split the list pane can fold away; the hero then
    // carries the control that brings it back, beside the back button, so
    // the page never overlays a second bar on its own chrome.
    final split = ListDetailFocusTraversal.maybeOf(context);
    final listHidden = split != null && !split.listPaneVisible;
    const glyphSize = GlassActionButton.defaultSize;

    final leading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassBackButton(
          onPressed: onBack,
          iconColor: ink,
          containerSize: glyphSize,
        ),
        if (listHidden) ...[
          SizedBox(width: tokens.spacing.step2),
          GlassActionButton(
            key: const ValueKey('people-show-list-pane'),
            tooltip: messages.listPaneShowTooltip,
            semanticLabel: messages.listPaneShowTooltip,
            onTap: split.showListPane,
            child: Icon(LottiIcons.sidebar, size: IconSizes.l, color: ink),
          ),
        ],
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (desktop)
          DesignSystemButton(
            key: const ValueKey('person-talk-to-agent'),
            label: messages.goalChatTalkToAgent,
            leadingIcon: LottiIcons.chat,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.dense,
            onPressed: onTalkToAgent,
          )
        else
          GlassActionButton(
            key: const ValueKey('person-talk-to-agent'),
            tooltip: messages.goalChatTalkToAgent,
            semanticLabel: messages.goalChatTalkToAgent,
            onTap: onTalkToAgent,
            child: Icon(LottiIcons.chat, size: IconSizes.l, color: ink),
          ),
        SizedBox(width: tokens.spacing.step2),
        GlassActionButton(
          key: const ValueKey('person-edit'),
          tooltip: messages.relationshipEditTitle,
          semanticLabel: messages.relationshipEditTitle,
          onTap: () => showRelationshipEditModal(
            context: context,
            relationship: relationship,
          ),
          child: Icon(LottiIcons.edit, size: IconSizes.l, color: ink),
        ),
        SizedBox(width: tokens.spacing.step2),
        PersonMenuButton(relationship: relationship, onDelete: onDelete),
      ],
    );

    return SliverPersistentHeader(
      key: const ValueKey('person-hero'),
      pinned: true,
      delegate: _PersonHeroDelegate(
        title: relationship.data.title,
        titleStyle: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: ink,
        ),
        wash: washColor(tokens),
        topPadding: MediaQuery.paddingOf(context).top,
        bandExtent: bandExtent(tokens),
        collapseSlack: tokens.spacing.step2,
        gutter: tokens.spacing.step3,
        avatar: PersonaAvatar(
          initial: personaInitial(relationship.data.title),
          id: relationship.id,
          size: avatarSize(tokens),
        ),
        avatarSize: avatarSize(tokens),
        avatarInset: contentInset,
        leading: leading,
        actions: actions,
      ),
    );
  }
}

/// The hero's layout at every scroll position: the wash behind everything,
/// the toolbar row pinned under the status bar, the name swapped in once the
/// band has folded, and the avatar hanging over the lower edge while the
/// band is open.
class _PersonHeroDelegate extends SliverPersistentHeaderDelegate {
  const _PersonHeroDelegate({
    required this.title,
    required this.titleStyle,
    required this.wash,
    required this.topPadding,
    required this.bandExtent,
    required this.collapseSlack,
    required this.gutter,
    required this.avatar,
    required this.avatarSize,
    required this.avatarInset,
    required this.leading,
    required this.actions,
  });

  final String title;
  final TextStyle titleStyle;
  final Color wash;
  final double topPadding;
  final double bandExtent;

  /// How close to fully collapsed counts as collapsed, so the name does not
  /// wait for the last sub-pixel of the band.
  final double collapseSlack;
  final double gutter;
  final Widget avatar;
  final double avatarSize;
  final double avatarInset;
  final Widget leading;
  final Widget actions;

  @override
  double get minExtent => topPadding + kToolbarHeight;

  @override
  double get maxExtent => minExtent + bandExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapsed = shrinkOffset >= bandExtent - collapseSlack;
    final bandOpen = 1 - (shrinkOffset / bandExtent).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        ColoredBox(key: const ValueKey('person-hero-wash'), color: wash),
        Positioned(
          top: topPadding,
          left: gutter,
          right: gutter,
          height: kToolbarHeight,
          child: Row(
            children: [
              leading,
              SizedBox(width: gutter),
              Expanded(
                // Swapped rather than faded: while the band is open the bar
                // holds nothing at all, so the name exists exactly once on
                // the page at any time.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: collapsed
                      ? Text(
                          title,
                          key: const ValueKey('person-hero-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(width: gutter),
              actions,
            ],
          ),
        ),
        // Fades with the band so it never sits on the collapsed toolbar's
        // edge, over whatever has scrolled under it.
        Positioned(
          left: avatarInset,
          bottom: -avatarSize / 2,
          child: IgnorePointer(
            child: Opacity(
              key: const ValueKey('person-hero-avatar'),
              opacity: bandOpen,
              child: avatar,
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_PersonHeroDelegate oldDelegate) =>
      title != oldDelegate.title ||
      titleStyle != oldDelegate.titleStyle ||
      wash != oldDelegate.wash ||
      topPadding != oldDelegate.topPadding ||
      bandExtent != oldDelegate.bandExtent ||
      avatarSize != oldDelegate.avatarSize ||
      avatarInset != oldDelegate.avatarInset ||
      avatar != oldDelegate.avatar ||
      leading != oldDelegate.leading ||
      actions != oldDelegate.actions;
}

/// What the hero's kebab offers: the contact-link intents where there is an
/// address book (ADR 0041), and delete — which says it takes the check-ins
/// with it.
enum PersonMenuAction { linkContact, refreshContact, relinkContact, delete }

/// The hero's overflow menu.
class PersonMenuButton extends ConsumerWidget {
  const PersonMenuButton({
    required this.relationship,
    required this.onDelete,
    super.key,
  });

  final RelationshipEntry relationship;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final ink = tokens.colors.text.highEmphasis;
    final contactsSupported = ref.read(contactsServiceProvider).isSupported;
    final linked =
        contactsSupported &&
        contactIsLinkedOnThisDevice(
          relationship,
          ref.watch(contactRefKeyProvider).value,
        );

    Widget item(IconData icon, String label, {Color? color}) => Row(
      children: [
        Icon(icon, color: color ?? ink),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: color ?? ink,
            ),
          ),
        ),
      ],
    );

    return PopupMenuButton<PersonMenuAction>(
      key: const ValueKey('person-menu'),
      tooltip: messages.relationshipMoreActions,
      icon: Icon(LottiIcons.moreVertical, color: ink),
      onSelected: (action) => unawaited(switch (action) {
        PersonMenuAction.linkContact ||
        PersonMenuAction.relinkContact => runContactLinkAction(
          context,
          ref,
          (controller) => controller.linkContact(relationship),
        ),
        PersonMenuAction.refreshContact => runContactLinkAction(
          context,
          ref,
          (controller) => controller.refreshFromContact(relationship),
        ),
        PersonMenuAction.delete => onDelete(),
      }),
      itemBuilder: (context) => [
        if (contactsSupported && !linked)
          PopupMenuItem(
            value: PersonMenuAction.linkContact,
            child: item(
              LottiIcons.findPerson,
              messages.relationshipLinkContact,
            ),
          ),
        if (linked) ...[
          PopupMenuItem(
            value: PersonMenuAction.refreshContact,
            child: item(
              LottiIcons.contactCard,
              messages.relationshipUpdateFromContact,
            ),
          ),
          PopupMenuItem(
            value: PersonMenuAction.relinkContact,
            child: item(
              LottiIcons.findPerson,
              messages.relationshipRelinkContact,
            ),
          ),
        ],
        PopupMenuItem(
          value: PersonMenuAction.delete,
          child: item(
            LottiIcons.delete,
            messages.deleteButton,
            color: tokens.colors.alert.error.ink,
          ),
        ),
      ],
    );
  }
}

/// The header block under the hero, starting below the avatar that hangs
/// off it: the eyebrow (`Penguin Operations · Important`), the full wrapping
/// name, the teal one-liner (`"Pip" · last spoke Today 12:44`), and the
/// pills — the cadence fact the deterministic tier always knows, the health
/// band once a briefing exists, and the next due day.
class PersonHeaderBlock extends StatelessWidget {
  const PersonHeaderBlock({
    required this.item,
    required this.categoryName,
    required this.healthBand,
    super.key,
  });

  final RelationshipListItem item;
  final String? categoryName;
  final RelationshipHealthBand? healthBand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = item.relationship.data;

    final eyebrow = [
      ?categoryName,
      if (data.important) messages.relationshipImportantLabel,
    ].join(' · ');
    final lastSpoke = item.lastCheckInAt == null
        ? messages.relationshipJustAdded
        : messages.relationshipLastSpoke(
            relationshipTimestampLabelOf(context, item.lastCheckInAt!),
          );
    final oneLiner = [
      if (data.nickname case final nickname? when nickname.isNotEmpty)
        '"$nickname"',
      lastSpoke,
    ].join(' · ');

    // No inset of its own: the page lays every section on the one content
    // gutter and spaces them, so the block lines up with the cards below.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room for the half of the avatar that hangs off the hero.
        SizedBox(
          height:
              PersonHeroAppBar.avatarSize(tokens) / 2 + tokens.spacing.step3,
        ),
        if (eyebrow.isNotEmpty) ...[
          Text(
            eyebrow,
            key: const ValueKey('person-eyebrow'),
            style: relationshipTimestampStyle(
              tokens,
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
        Text(
          data.title,
          style: tokens.typography.styles.heading.heading2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          oneLiner,
          key: const ValueKey('person-one-liner'),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.interactive.enabled,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: personHeaderPills(context, item, healthBand: healthBand),
        ),
      ],
    );
  }
}

/// The header pills, in order: the cadence fact (on track · cadence, or due
/// since · days over), the health band, the next due day.
List<Widget> personHeaderPills(
  BuildContext context,
  RelationshipListItem item, {
  required RelationshipHealthBand? healthBand,
}) {
  final tokens = context.designTokens;
  final messages = context.messages;
  final pill = peopleCadencePillOf(item);
  final quiet = tokens.colors.text.mediumEmphasis;
  final pills = <Widget>[];

  switch (pill.kind) {
    case PeopleCadencePillKind.overdue:
      pills.add(
        DsPill(
          key: const ValueKey('person-pill-due'),
          variant: DsPillVariant.tinted,
          shape: DsPillShape.tag,
          color: tokens.colors.alert.warning.defaultColor,
          labelColor: tokens.colors.text.highEmphasis,
          label: messages.relationshipDueSince(
            relationshipWeekdayLabelOf(
              context,
              peopleDueDateOf(item)!,
            ),
            pill.daysOver,
          ),
        ),
      );
    case PeopleCadencePillKind.dueSoon || PeopleCadencePillKind.onTrack:
      pills.add(
        DsPill(
          key: const ValueKey('person-pill-cadence'),
          variant: DsPillVariant.filled,
          shape: DsPillShape.tag,
          leading: Icon(LottiIcons.confirm, size: IconSizes.s, color: quiet),
          labelColor: quiet,
          // The effective cadence, not the stored one: an enrolled person
          // with no cadence set is on the runtime's default, and the pill
          // says which rhythm actually governs the due date.
          label: messages.relationshipOnTrackCadence(
            relationshipCadenceLabel(
              context,
              effectiveCadenceDaysOf(item.relationship),
            ),
          ),
        ),
      );
    case PeopleCadencePillKind.notEnrolled ||
        PeopleCadencePillKind.dormant ||
        PeopleCadencePillKind.archived:
      pills.add(
        DsPill(
          key: const ValueKey('person-pill-status'),
          variant: DsPillVariant.filled,
          shape: DsPillShape.tag,
          labelColor: quiet,
          label: switch (pill.kind) {
            PeopleCadencePillKind.dormant => messages.relationshipStatusDormant,
            PeopleCadencePillKind.archived =>
              messages.relationshipStatusArchived,
            _ => messages.relationshipNotEnrolled,
          },
        ),
      );
  }

  if (healthBand != null) {
    pills.add(
      DsPill(
        key: const ValueKey('person-pill-health'),
        variant: DsPillVariant.tinted,
        shape: DsPillShape.tag,
        color: relationshipHealthBandColor(tokens, healthBand),
        labelColor: tokens.colors.text.highEmphasis,
        label: relationshipHealthBandLabel(context, healthBand),
      ),
    );
  }

  final due = peopleDueDateOf(item);
  if (due != null &&
      (pill.kind == PeopleCadencePillKind.dueSoon ||
          pill.kind == PeopleCadencePillKind.onTrack)) {
    pills.add(
      DsPill(
        key: const ValueKey('person-pill-next-due'),
        variant: DsPillVariant.filled,
        shape: DsPillShape.tag,
        leading: Icon(LottiIcons.today, size: IconSizes.s, color: quiet),
        labelColor: quiet,
        label: messages.relationshipNextDueOn(
          relationshipDayLabelOf(context, due),
        ),
      ),
    );
  }
  return pills;
}

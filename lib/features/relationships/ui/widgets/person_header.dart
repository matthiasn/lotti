import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/photo_chrome_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/contact_import_controller.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/cadence_pill.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_link_action.dart';
import 'package:lotti/features/relationships/ui/widgets/person_reminders_pill.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// The person page's cover-style hero (design 2026-09-06 §2–3): a teal wash
/// with no imagery, carrying back · Talk to agent · edit · kebab, with the
/// persona avatar overlapping its lower edge. Pinned, so the actions stay
/// reachable while the page scrolls; once the wash band has folded away
/// the bar names the person the hero itself leaves to the header block.
///
/// A persistent header of its own rather than a `SliverAppBar`, for the
/// avatar's overhang. The half of it below the wash is *part of the hero's
/// extent*, left transparent, so the whole avatar sits inside the sliver —
/// a sliver only hit-tests within its own extent, and an avatar hanging past
/// it would be a button whose lower half does nothing. An app bar paints its
/// background over its whole extent and could not leave that strip clear.
/// Slivers paint back to front, so the header — earlier in the list — still
/// paints the avatar over the content scrolling under it.
class PersonHeroAppBar extends StatelessWidget {
  const PersonHeroAppBar({
    required this.relationship,
    required this.onBack,
    required this.onTalkToAgent,
    required this.onDelete,
    required this.hasAgent,
    this.onAvatarTap,
    this.contentInset = 0,
    super.key,
  });

  final RelationshipEntry relationship;
  final VoidCallback onBack;
  final VoidCallback onTalkToAgent;
  final Future<void> Function() onDelete;

  /// Whether this person has an agent to talk to.
  ///
  /// Not the same question as whether reminders are on. Unmarking someone,
  /// or making them dormant, stops the cadence but deliberately keeps the
  /// agent and its conversation — so gating this entry on enrolment would
  /// take away the only ordinary way back into a chat that still exists
  /// and still works at `/people/<id>/chat`. The page resolves it, because
  /// the page is what watches the agent.
  final bool hasAgent;

  /// Tapping the avatar — the door to the person's photo (design 2026-09-08
  /// turn 2, the avatar tap sheet). Only while the band is open: once the
  /// hero has folded, the avatar has faded and must not catch taps meant
  /// for the content scrolling under it.
  final VoidCallback? onAvatarTap;

  /// The page's horizontal content inset, so the avatar lines up with the
  /// header block's left edge — the gutter on a phone, the centred column's
  /// edge on a desktop window.
  final double contentInset;

  /// The wash band's extent below the toolbar: the avatar overlaps its lower
  /// edge by half its diameter, so the band has to be tall enough to read
  /// as a band rather than a stripe.
  static double bandExtent(DsTokens tokens) => tokens.spacing.step12;

  /// The avatar diameter; half of it hangs below the hero.
  static const double avatarSize = ControlSizes.avatarHero;

  /// The banner strip's height at rest: the folded hero and the whole band —
  /// everything above the avatar's midline. The Photo card's preview mirrors
  /// it, and the strip's decode is bounded to it so a scroll never re-keys
  /// the picture. The same sum the delegate's `bannerStripAtRest` is, over
  /// the one [_heroMinExtent], so the two cannot drift.
  static double bannerStripExtent(
    DsTokens tokens, {
    required double topPadding,
  }) => _heroMinExtent(topPadding) + bandExtent(tokens);

  /// The wash itself: a decorative tint over the page surface — the same
  /// recipe every tone-tinted card fill uses, on the decorative token
  /// rather than the interactive one.
  ///
  /// It used to blend `interactive.enabled`, which spent the app's one
  /// accent on a person who simply has no banner yet. On the not-enrolled
  /// page — the one page with no agent and nothing teal to justify — that
  /// made the header the most saturated surface in the feature, so teal
  /// stopped meaning "you can press this" anywhere on it.
  static Color washColor(DsTokens tokens) => Color.alphaBlend(
    tokens.colors.decorative.level02.withValues(alpha: SurfaceAlphas.tint),
    tokens.colors.background.level01,
  );

  @override
  Widget build(BuildContext context) {
    final bannerId = relationship.data.bannerImageId;
    if (bannerId == null) return _build(context, banner: null);
    // The banner's file may not be on disk yet; the resolver rebuilds the
    // hero when it lands. A component in a sliver slot is fine — the sliver
    // is what it returns. With nothing to show, the hero is the wash exactly
    // as it is without a banner.
    return JournalImageResolver(
      imageId: bannerId,
      builder: (context, resolved) => _build(
        context,
        banner: resolved == null || resolved.hasNothingToShow ? null : resolved,
      ),
    );
  }

  Widget _build(BuildContext context, {required ResolvedJournalImage? banner}) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final desktop = isDesktopLayout(context);
    // Over a photograph the chrome goes photo-neutral: the theme's ink is
    // near-black in the light theme and would vanish on a picture.
    final onPhoto = banner != null;
    final ink = onPhoto
        ? PhotoNeutralGlass.glyph
        : tokens.colors.text.highEmphasis;
    final glassFill = onPhoto ? PhotoNeutralGlass.fill : null;
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
          backgroundColor: glassFill,
          containerSize: glyphSize,
        ),
        if (listHidden) ...[
          SizedBox(width: tokens.spacing.step2),
          GlassActionButton(
            key: const ValueKey('people-show-list-pane'),
            tooltip: messages.listPaneShowTooltip,
            semanticLabel: messages.listPaneShowTooltip,
            fill: glassFill,
            onTap: split.showListPane,
            child: Icon(LottiIcons.sidebar, size: IconSizes.l, color: ink),
          ),
        ],
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The agent entry, and only where there is an agent. It carried
        // `LottiIcons.chat` — the same speech bubble the Reach card spends
        // on "text this human" — so one page showed two bubbles meaning
        // two different correspondents. The sparkle already means "the
        // agent" everywhere else in the app, so it means it here.
        //
        // It is hidden, not disabled, when there is no agent: a chat
        // bubble above "No agent for this person" offered a conversation
        // with something that does not exist.
        if (hasAgent) ...[
          if (desktop)
            DesignSystemButton(
              key: const ValueKey('person-talk-to-agent'),
              label: messages.goalChatTalkToAgent,
              leadingIcon: LottiIcons.aiSpark,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.dense,
              onPressed: onTalkToAgent,
            )
          else
            GlassActionButton(
              key: const ValueKey('person-talk-to-agent'),
              tooltip: messages.goalChatTalkToAgent,
              semanticLabel: messages.goalChatTalkToAgent,
              fill: glassFill,
              onTap: onTalkToAgent,
              child: Icon(LottiIcons.aiSpark, size: IconSizes.l, color: ink),
            ),
          SizedBox(width: tokens.spacing.step2),
        ],
        GlassActionButton(
          key: const ValueKey('person-edit'),
          tooltip: messages.relationshipEditTitle,
          semanticLabel: messages.relationshipEditTitle,
          fill: glassFill,
          onTap: () => showRelationshipEditModal(
            context: context,
            relationship: relationship,
          ),
          child: Icon(LottiIcons.edit, size: IconSizes.l, color: ink),
        ),
        SizedBox(width: tokens.spacing.step2),
        PersonMenuButton(
          relationship: relationship,
          onDelete: onDelete,
          glyphColor: ink,
          // The same disc the back, chat and edit buttons wear. Without it
          // the kebab — which holds delete — was a bare white glyph on a
          // user's own photograph, the only hero control with nothing
          // behind it.
          fill: glassFill,
        ),
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
          size: avatarSize,
          imageId: relationship.data.avatarImageId,
          crop: relationship.data.avatarCrop,
        ),
        avatarSize: avatarSize,
        avatarInset: contentInset,
        avatarSemanticsLabel: messages.relationshipPhotoSheetTitle(
          relationship.data.title,
        ),
        onAvatarTap: onAvatarTap,
        banner: banner,
        bannerCropX: relationship.data.bannerCropX,
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
    required this.avatarSemanticsLabel,
    required this.onAvatarTap,
    required this.banner,
    required this.bannerCropX,
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
  final String avatarSemanticsLabel;
  final VoidCallback? onAvatarTap;

  /// The banner as it can be drawn right now — file or stand-in — or null
  /// for the wash alone.
  final ResolvedJournalImage? banner;
  final double bannerCropX;
  final Widget leading;
  final Widget actions;

  @override
  double get minExtent => _heroMinExtent(topPadding);

  /// The half of the avatar below the wash, carried as transparent extent so
  /// the avatar is whole inside the sliver.
  double get overhang => avatarSize / 2;

  /// Everything that folds: the band and the overhang under it.
  double get foldable => bandExtent + overhang;

  /// The banner strip at rest — everything above the avatar's midline.
  /// Fixed, so the scrim's extent and the decode's bound do not move with
  /// the scroll.
  double get bannerStripAtRest => minExtent + bandExtent;

  @override
  double get maxExtent => minExtent + foldable;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapsed = shrinkOffset >= foldable - collapseSlack;
    final bandOpen = 1 - (shrinkOffset / foldable).clamp(0.0, 1.0);
    // The clear strip under the band closes before the band itself folds,
    // so the wash — or the picture — keeps its height for the first
    // half-diameter of scroll while the avatar tucks up into it.
    final overhangOpen = (overhang - shrinkOffset).clamp(0.0, overhang);
    // With a banner, the picture is the whole hero above the avatar's
    // midline — the toolbar and the band — and there is no wash at all:
    // the avatar straddles the picture's lower edge. Folding, the picture
    // keeps its height while the avatar tucks up into it, then shrinks with
    // the band to the toolbar, so at rest and collapsed alike the actions
    // sit on the picture — under the scrim, whose extent is fixed in pixels
    // for exactly that reason.
    // A pinned sliver's shrinkOffset runs on to maxExtent on a deep scroll;
    // the box itself never gets shorter than minExtent, and neither may
    // the strip — or the banner would vanish behind the toolbar.
    final extent = math.max(minExtent, maxExtent - shrinkOffset);
    final bandBottom = extent - overhangOpen;
    final banner = this.banner;
    final stripExtent = banner == null ? 0.0 : bandBottom;
    final scrimExtent = math.min(
      stripExtent,
      bannerStripAtRest * PhotoScrim.fadeExtent,
    );

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        if (banner != null) ...[
          Positioned(
            key: const ValueKey('person-hero-banner'),
            top: 0,
            left: 0,
            right: 0,
            height: stripExtent,
            child: LayoutBuilder(
              builder: (context, constraints) => ThumbHashBackedImage(
                key: ValueKey(banner.path),
                thumbHash: banner.thumbHash,
                image: banner.fileExists
                    ? boundedFileImage(
                        banner.path,
                        bounds: Size(constraints.maxWidth, bannerStripAtRest),
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                      )
                    : null,
                alignment: Alignment(bannerCropX * 2 - 1, 0),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey('person-hero-scrim'),
            top: 0,
            left: 0,
            right: 0,
            height: scrimExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    PhotoScrim.color.withValues(alpha: PhotoScrim.topAlpha),
                    PhotoScrim.color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ] else
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: overhangOpen,
            child: ColoredBox(
              key: const ValueKey('person-hero-wash'),
              color: wash,
            ),
          ),
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
        // edge, over whatever has scrolled under it — and stops taking taps
        // at the same moment, so a faded avatar cannot intercept the content.
        // Anchored to the hero's own bottom: at rest that is half a diameter
        // below the wash, and every pixel of it is inside the sliver.
        Positioned(
          left: avatarInset,
          bottom: 0,
          child: IgnorePointer(
            ignoring: collapsed || onAvatarTap == null,
            child: Opacity(
              key: const ValueKey('person-hero-avatar'),
              opacity: bandOpen,
              // The initial inside the circle is decoration to a screen
              // reader; the label says what the tap opens.
              child: Semantics(
                button: onAvatarTap != null,
                label: avatarSemanticsLabel,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('person-hero-avatar-tap'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAvatarTap,
                  child: avatar,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Always: [PersonHeroAppBar] builds a fresh [avatar], [leading] and
  /// [actions] on every build, and widgets compare by identity, so a
  /// field-by-field comparison could never say "unchanged" — the delegate
  /// repaints whenever its host rebuilds, and this says so plainly rather
  /// than through fourteen comparisons that the first widget field decides.
  @override
  bool shouldRebuild(_PersonHeroDelegate oldDelegate) => true;
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
    this.glyphColor,
    this.fill,
    super.key,
  });

  final RelationshipEntry relationship;
  final Future<void> Function() onDelete;

  /// The kebab's glyph. Null is the theme's ink; the hero passes the
  /// photo-neutral glyph while it sits on a banner.
  final Color? glyphColor;

  /// The disc behind the glyph, matching the hero's other actions. Null
  /// where the trigger does not sit on a photograph.
  final Color? fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The trigger sits on the hero, possibly on a photograph; the menu's
    // rows sit on the popup's own surface and keep the theme's ink — the
    // neutral white glyph would vanish on a light popup.
    final triggerInk = glyphColor ?? tokens.colors.text.highEmphasis;
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
      style: fill == null ? null : IconButton.styleFrom(backgroundColor: fill),
      icon: Icon(LottiIcons.moreVertical, color: triggerInk),
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
/// name, the quiet one-liner (`"Pip" · last spoke Today 12:44`, its
/// timestamp in the mono voice), and the pills — the cadence fact the
/// deterministic tier always knows, and the next due day.
///
/// The health band is deliberately *not* here: the briefing card carries it
/// with the age that makes it true.
class PersonHeaderBlock extends StatelessWidget {
  const PersonHeaderBlock({
    required this.item,
    required this.categoryName,
    super.key,
  });

  final RelationshipListItem item;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = item.relationship.data;

    // The category alone: that reminders are on, and how often, is the
    // reminders pill's to say — it says it in every state and can change it.
    final eyebrow = categoryName ?? '';
    // The timestamp inside the one-liner, kept as its own substring so the
    // mono voice can be confined to it below — the same rule the list row
    // follows, so one point in time never renders in two typefaces on one
    // screen.
    final spokeAt = item.lastCheckInAt == null
        ? null
        : relationshipTimestampLabelOf(context, item.lastCheckInAt!);
    final lastSpoke = spokeAt == null
        ? messages.relationshipJustAdded
        : messages.relationshipLastSpoke(spokeAt);
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
        // The hero's own extent already covers the half of the avatar
        // below the wash; this is only the breathing room under it — and it
        // is the break between the picture and the identity, so it gets the
        // section gap rather than the smallest step in the stack.
        SizedBox(height: tokens.spacing.sectionGap),
        if (eyebrow.isNotEmpty) ...[
          Text(
            eyebrow,
            key: const ValueKey('person-eyebrow'),
            // `Penguin Operations · Important` is a label, not a reading on
            // a clock. It used to borrow the mono timestamp style, which
            // made the first string on the page the only monospaced one and
            // cost it the measure the category name needs.
            style: calmEyebrowStyle(
              tokens,
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
        Text(
          data.title,
          style: calmPageTitleStyle(tokens),
        ),
        SizedBox(height: tokens.spacing.step1),
        // Quiet, not teal. Nothing on this line is tappable, and the
        // interactive token on a whole non-interactive line both promised a
        // tap that never came and outranked the person's own name — the one
        // string in the block that should win.
        RelationshipLineWithDate(
          key: const ValueKey('person-one-liner'),
          text: oneLiner,
          date: spokeAt,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: personHeaderPills(context, item),
        ),
      ],
    );
  }
}

/// The header pills, in order: the cadence fact (on track, or due since ·
/// days over), the reminders pill with the interval — for an enrolled person,
/// in every state — and the next due day.
///
/// One tinted chip at most, and it is the cadence: the health band lives on
/// the briefing card, which dates it.
List<Widget> personHeaderPills(
  BuildContext context,
  RelationshipListItem item,
) {
  final tokens = context.designTokens;
  final messages = context.messages;
  final pill = peopleCadencePillOf(item);
  final quiet = tokens.colors.text.mediumEmphasis;
  final pills = <Widget>[
    relationshipCadencePill(context, item),
    // `isEnrolled`, not the raw flag: a dormant or archived person keeps
    // `important` while the runtime clears their reminders.
    if (isEnrolled(item.relationship))
      PersonRemindersPill(relationship: item.relationship),
  ];

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

/// The cadence fact as one pill, from the list model's own rules so the
/// header and the list never disagree about *due*: a warning-tinted `Due
/// since {day} · {n} days over` when lapsed, `On track` while enrolled — the
/// interval itself is [PersonRemindersPill]'s — and the status word for
/// everyone else.
///
/// Keyed per kind (`<keyPrefix>-due` / `-cadence` / `-status`) so a test can
/// say which fact it expects rather than which text.
Widget relationshipCadencePill(
  BuildContext context,
  RelationshipListItem item, {
  String keyPrefix = 'person-pill',
}) {
  final tokens = context.designTokens;
  final messages = context.messages;
  final pill = peopleCadencePillOf(item);
  final quiet = tokens.colors.text.mediumEmphasis;

  return switch (pill.kind) {
    // One encoding for a lapsed cadence, shared with the People row: the
    // header spells more of it out, but it must not *look* like a
    // different state.
    PeopleCadencePillKind.overdue => relationshipOverduePill(
      context,
      pillKey: ValueKey('$keyPrefix-due'),
      label: messages.relationshipDueSince(
        relationshipWeekdayLabelOf(context, peopleDueDateOf(item)!),
        pill.daysOver,
      ),
    ),
    PeopleCadencePillKind.dueSoon || PeopleCadencePillKind.onTrack => DsPill(
      key: ValueKey('$keyPrefix-cadence'),
      variant: DsPillVariant.filled,
      shape: DsPillShape.tag,
      leading: Icon(LottiIcons.confirm, size: IconSizes.s, color: quiet),
      labelColor: quiet,
      // The state alone: the interval rides the reminders pill beside it,
      // which carries it in the overdue state too.
      label: messages.relationshipCadenceOnTrack,
    ),
    PeopleCadencePillKind.notEnrolled ||
    PeopleCadencePillKind.dormant ||
    PeopleCadencePillKind.archived => DsPill(
      key: ValueKey('$keyPrefix-status'),
      variant: DsPillVariant.filled,
      shape: DsPillShape.tag,
      labelColor: quiet,
      label: switch (pill.kind) {
        PeopleCadencePillKind.dormant => messages.relationshipStatusDormant,
        PeopleCadencePillKind.archived => messages.relationshipStatusArchived,
        _ => messages.relationshipNotEnrolled,
      },
    ),
  };
}

/// The folded hero — the status inset and the toolbar — in one place: the
/// delegate's `minExtent` and [PersonHeroAppBar.bannerStripExtent] both read
/// it, so the decode bound, the scrim and the Photo card's preview agree with
/// the hero's own height by construction.
double _heroMinExtent(double topPadding) => topPadding + kToolbarHeight;

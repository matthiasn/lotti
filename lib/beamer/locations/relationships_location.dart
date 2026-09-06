import 'package:beamer/beamer.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_chat_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationships_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// The flag-gated People tab (`enable_relationships`): the list of tracked
/// relationships and the per-person detail with its check-in log.
///
/// On desktop the person page lives in the list/detail split's right pane
/// (the Projects pattern): the location mirrors the URL's person id into
/// `NavService.desktopSelectedRelationshipId` and pushes no detail page. The
/// chat is a second face of that same pane rather than a stacked route
/// (design 2026-09-06 §6), so `/chat` sets
/// `NavService.desktopRelationshipChatOpen` there and still pushes a page
/// only on phones.
class RelationshipsLocation extends BeamLocation<BeamState> {
  RelationshipsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/people',
    '/people/:relationshipId',
    '/people/:relationshipId/chat',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final relationshipId = state.pathParameters['relationshipId'];
    final messages = context.messages;
    final navService = getIt<NavService>();
    final isDesktop = navService.isDesktopMode;
    final isChat =
        relationshipId != null &&
        state.uri.pathSegments.length == 3 &&
        state.uri.pathSegments[2] == 'chat';
    if (isDesktop) {
      navService.desktopSelectedRelationshipId.value = relationshipId;
      navService.desktopRelationshipChatOpen.value = isChat;
    }
    return [
      BeamPage(
        key: const ValueKey('people'),
        title: messages.relationshipsPageTitle,
        child: const RelationshipsPage(),
      ),
      // The detail page's own SliverAppBar shows the person's name; the
      // BeamPage title is left unset so the window/tab bar falls back to
      // the app name rather than misreading "People" for one person.
      if (!isDesktop && relationshipId != null)
        BeamPage(
          key: ValueKey('people-details-$relationshipId'),
          child: RelationshipDetailsPage(relationshipId: relationshipId),
        ),
      if (!isDesktop && isChat)
        BeamPage(
          key: ValueKey('people-chat-$relationshipId'),
          child: RelationshipChatPage(relationshipId: relationshipId),
        ),
    ];
  }
}

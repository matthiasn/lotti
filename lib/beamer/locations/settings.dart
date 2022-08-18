import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:lotti/pages/settings/tags/create_tag_page.dart';
import 'package:lotti/pages/settings/tags/tag_edit_page.dart';
import 'package:lotti/pages/settings/tags/tags_page.dart';

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/settings',
        '/settings/tags',
        '/settings/tags/:tagEntityId',
        '/settings/tags/create/:tagType',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final pages = [
      const BeamPage(
        key: ValueKey('settings'),
        title: 'Settings',
        type: BeamPageType.noTransition,
        child: SettingsPage(),
      ),
    ];

    if (state.uri.path.contains('tags')) {
      pages.add(
        const BeamPage(
          key: ValueKey('settings-tags'),
          child: TagsPage(),
        ),
      );
    }

    if (state.uri.path.contains('tags') &&
        !state.uri.path.contains('create') &&
        state.pathParameters.containsKey('tagEntityId')) {
      pages.add(
        BeamPage(
          key: ValueKey(
            'settings-tags-${state.pathParameters['tagEntityId']}',
          ),
          child: EditExistingTagPage(
            tagEntityId: state.pathParameters['tagEntityId']!,
          ),
        ),
      );
    }

    if (state.uri.path.contains('tags/create') &&
        state.pathParameters.containsKey('tagType')) {
      pages.add(
        BeamPage(
          key: ValueKey(
            'settings-tags-create-${state.pathParameters['tagType']}',
          ),
          child: CreateTagPage(tagType: state.pathParameters['tagType']!),
        ),
      );
    }

    return pages;
  }
}

class ConfigFlagsLocation extends BeamLocation<BeamState> {
  ConfigFlagsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/config_flags/'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('settings'),
          title: 'Settings',
          type: BeamPageType.noTransition,
          child: FlagsPage(),
        ),
      ];
}

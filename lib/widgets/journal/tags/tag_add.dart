import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/tags/tags_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagAddIconWidget extends StatelessWidget {
  TagAddIconWidget({super.key});

  final TagsService tagsService = getIt<TagsService>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<TagEntity>>(
      stream: tagsService.stream,
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagEntity>> _,
      ) {
        return BlocBuilder<EntryCubit, EntryState>(
          builder: (
            context,
            EntryState state,
          ) {
            final item = state.entry;
            if (item == null) {
              return const SizedBox.shrink();
            }

            final controller = TextEditingController();

            void onTapAdd() {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                isDismissible: Platform.isMacOS,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                builder: (_) {
                  return BlocProvider.value(
                    value: BlocProvider.of<EntryCubit>(context),
                    child: TagsModal(controller: controller),
                  );
                },
              );
            }

            return SizedBox(
              width: 40,
              child: IconButton(
                onPressed: onTapAdd,
                icon: Icon(
                  MdiIcons.tagPlusOutline,
                  size: 24,
                  color: colorConfig().iron,
                ),
                tooltip: localizations.journalTagPlusHint,
              ),
            );
          },
        );
      },
    );
  }
}

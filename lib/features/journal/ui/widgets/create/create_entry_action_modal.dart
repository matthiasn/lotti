import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/index.dart';

class CreateEntryModal {
  static Future<void> show({
    required BuildContext context,
    required String? linkedFromId,
    required String? categoryId,
  }) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.createEntryTitle,
      padding: const EdgeInsets.only(bottom: 30, top: 10),
      builder: (modalContext) => _CreateEntryMenuList(
        linkedFromId: linkedFromId,
        categoryId: categoryId,
      ),
    );
  }
}

/// Builds the list of create entry items with dividers between them.
class _CreateEntryMenuList extends StatelessWidget {
  const _CreateEntryMenuList({
    required this.linkedFromId,
    required this.categoryId,
  });

  final String? linkedFromId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      CreateEventItem(linkedFromId, categoryId: categoryId),
      CreateTaskItem(linkedFromId, categoryId: categoryId),
      CreateAudioItem(linkedFromId, categoryId: categoryId),
      if (linkedFromId != null) CreateTimerItem(linkedFromId!),
      CreateTextItem(linkedFromId, categoryId: categoryId),
      if (isMacOS || isMobile)
        ImportImageItem(linkedFromId, categoryId: categoryId),
      if (isMacOS || isLinux)
        CreateScreenshotItem(linkedFromId, categoryId: categoryId),
      PasteImageItem(linkedFromId, categoryId: categoryId),
    ];

    // Filter out SizedBox.shrink() widgets used to hide conditional items
    // to ensure dividers only appear between visible items
    final visibleItems = items.where((widget) {
      if (widget is SizedBox) {
        return widget.width != 0.0 || widget.height != 0.0;
      }
      return true;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visibleItems.length; i++) ...[
          visibleItems[i],
          if (i < visibleItems.length - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: AppTheme.cardPadding,
              endIndent: AppTheme.cardPadding,
              color: context.colorScheme.outline
                  .withValues(alpha: AppTheme.alphaDivider),
            ),
        ],
      ],
    );
  }
}

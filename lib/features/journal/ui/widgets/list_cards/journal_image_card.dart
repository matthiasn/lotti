import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/services/nav_service.dart';

const double iconSize = 18;

class JournalImageCard extends StatelessWidget {
  const JournalImageCard({
    required this.item,
    super.key,
  });

  final JournalImage item;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/journal/${item.meta.id}');
    if (item.meta.deletedAt != null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(right: 16),
        onTap: onTap,
        minLeadingWidth: 0,
        minVerticalPadding: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LimitedBox(
              maxWidth: max(MediaQuery.of(context).size.width / 2, 300) - 40,
              maxHeight: 160,
              child: CardImageWidget(
                journalImage: item,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: SizedBox(
                height: 160,
                child: JournalCardTitle(
                  item: item,
                  maxHeight: 200,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

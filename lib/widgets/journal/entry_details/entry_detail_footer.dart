import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/duration_widget.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

class EntryDetailFooter extends StatefulWidget {
  const EntryDetailFooter({
    super.key,
    required this.itemId,
    required this.popOnDelete,
  });

  final String itemId;
  final bool popOnDelete;

  @override
  State<EntryDetailFooter> createState() => _EntryDetailFooterState();
}

class _EntryDetailFooterState extends State<EntryDetailFooter> {
  bool mapVisible = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, EntryState state) {
        final item = state.entry;
        final loc = item?.geolocation;

        if (item == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DurationWidget(
                    item: item,
                    style: textStyle(),
                  ),
                  Visibility(
                    visible: loc != null && loc.longitude != 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              mapVisible = !mapVisible;
                            }),
                            child: Text(
                              '📍 ${formatLatLon(loc?.latitude)}, '
                              '${formatLatLon(loc?.longitude)}',
                              style: textStyle(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DeleteIconWidget(
                        popOnDelete: widget.popOnDelete,
                      ),
                      const ShareButtonWidget(),
                    ],
                  ),
                ],
              ),
            ),
            Visibility(
              visible: mapVisible,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: MapWidget(
                  geolocation: item.geolocation,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_details/duration_widget.dart';
import 'package:lotti/widgets/journal/entry_details/entry_datetime_widget.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

class EntryDetailFooter extends StatefulWidget {
  const EntryDetailFooter({
    super.key,
  });

  @override
  State<EntryDetailFooter> createState() => _EntryDetailFooterState();
}

class _EntryDetailFooterState extends State<EntryDetailFooter> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, EntryState state) {
        final item = state.entry;
        final cubit = context.read<EntryCubit>();

        if (item == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const EntryDatetimeWidget(),
                DurationWidget(
                  item: item,
                  style: textStyle(),
                ),
              ],
            ),
            Visibility(
              visible: cubit.showMap,
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

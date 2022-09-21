import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_details/entry_datetime_modal.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class EntryDatetimeWidget extends StatelessWidget {
  const EntryDatetimeWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, EntryState state) {
        final item = state.entry;

        if (item == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: TextButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                builder: (BuildContext _) {
                  return BlocProvider.value(
                    value: BlocProvider.of<EntryCubit>(context),
                    child: EntryDateTimeModal(item: item),
                  );
                },
              );
            },
            child: Text(
              df.format(item.meta.dateFrom),
              style: textStyle().copyWith(fontFamily: 'Inconsolata'),
            ),
          ),
        );
      },
    );
  }
}

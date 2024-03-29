import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/themes/theme.dart';

class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState state,
      ) {
        final unsaved = state.map(
          dirty: (_) => true,
          saved: (_) => false,
        );
        if (!unsaved) {
          return const SizedBox.shrink();
        }
        return TextButton(
          onPressed: () {
            context.read<EntryCubit>().save();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              localizations.saveLabel,
              style: saveButtonStyle(Theme.of(context)),
            ),
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 500));
      },
    );
  }
}

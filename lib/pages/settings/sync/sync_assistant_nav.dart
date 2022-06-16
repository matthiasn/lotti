import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/theme.dart';

class AlignedNavIcon extends StatelessWidget {
  const AlignedNavIcon({
    super.key,
    required this.onPressed,
    required this.iconData,
    required this.alignment,
  });

  final void Function() onPressed;
  final IconData iconData;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FadeIn(
        duration: const Duration(seconds: 2),
        child: IconButton(
          padding: const EdgeInsets.all(12),
          icon: Icon(
            iconData,
            color: AppColors.entryTextColor,
            size: 32,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class SyncNavPrevious extends StatelessWidget {
  const SyncNavPrevious({
    super.key,
    required this.pageCtrl,
    required this.notifier,
  });

  final PageController pageCtrl;
  final ValueNotifier<double> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (BuildContext context, double notifierValue, _) {
        return Visibility(
          visible: notifierValue != 0,
          child: AlignedNavIcon(
            alignment: Alignment.centerLeft,
            iconData: Icons.arrow_back_ios_rounded,
            onPressed: () {
              pageCtrl.previousPage(
                duration: const Duration(milliseconds: 600),
                curve: Curves.linear,
              );
            },
          ),
        );
      },
    );
  }
}

class SyncNavNext extends StatelessWidget {
  const SyncNavNext({
    super.key,
    required this.pageCtrl,
    required this.guardedPage,
    required this.guardedPagesAllowed,
    required this.notifier,
    required this.pageCount,
  });

  final PageController pageCtrl;
  final int guardedPage;
  final Map<int, bool Function(SyncConfigState)> guardedPagesAllowed;
  final int pageCount;
  final ValueNotifier<double> notifier;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return ValueListenableBuilder(
          valueListenable: notifier,
          builder: (BuildContext context, double notifierValue, _) {
            final isLastPage = notifierValue == pageCount - 1;
            final isGuardedPage = guardedPagesAllowed[notifierValue] != null;
            final allowedCheckFn = guardedPagesAllowed[notifierValue];
            final allowProceed =
                allowedCheckFn != null && allowedCheckFn(state);

            final visible = !isLastPage && (!isGuardedPage || allowProceed);

            return Visibility(
              visible: visible,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AlignedNavIcon(
                  alignment: Alignment.centerRight,
                  iconData: Icons.arrow_forward_ios_rounded,
                  onPressed: () {
                    pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.linear,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

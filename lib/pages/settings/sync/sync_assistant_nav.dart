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
    this.fadeInController,
  });

  final void Function() onPressed;
  final IconData iconData;
  final AlignmentGeometry alignment;
  final FadeInController? fadeInController;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FadeIn(
        controller: fadeInController,
        duration: const Duration(seconds: 1),
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

class SyncNavPrevious extends StatefulWidget {
  const SyncNavPrevious({
    super.key,
    required this.pageCtrl,
    required this.notifier,
  });

  final PageController pageCtrl;
  final ValueNotifier<double> notifier;

  @override
  State<SyncNavPrevious> createState() => _SyncNavPreviousState();
}

class _SyncNavPreviousState extends State<SyncNavPrevious> {
  final FadeInController fadeInController = FadeInController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.notifier,
      builder: (BuildContext context, double notifierValue, _) {
        if (notifierValue != 0) {
          fadeInController.fadeIn();
        } else {
          fadeInController.fadeOut();
        }

        return AlignedNavIcon(
          fadeInController: fadeInController,
          alignment: Alignment.centerLeft,
          iconData: Icons.arrow_back_ios_rounded,
          onPressed: () {
            widget.pageCtrl.previousPage(
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
            );
          },
        );
      },
    );
  }
}

class SyncNavNext extends StatefulWidget {
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
  State<SyncNavNext> createState() => _SyncNavNextState();
}

class _SyncNavNextState extends State<SyncNavNext> {
  final FadeInController fadeInController = FadeInController();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
      builder: (context, SyncConfigState state) {
        return ValueListenableBuilder(
          valueListenable: widget.notifier,
          builder: (BuildContext context, double notifierValue, _) {
            final isLastPage = notifierValue == widget.pageCount - 1;
            final isGuardedPage =
                widget.guardedPagesAllowed[notifierValue] != null;
            final allowedCheckFn = widget.guardedPagesAllowed[notifierValue];
            final allowProceed =
                allowedCheckFn != null && allowedCheckFn(state);

            final visible = !isLastPage && (!isGuardedPage || allowProceed);

            if (visible) {
              fadeInController.fadeIn();
            } else {
              fadeInController.fadeOut();
            }

            return Padding(
              padding: const EdgeInsets.all(8),
              child: AlignedNavIcon(
                fadeInController: fadeInController,
                alignment: Alignment.centerRight,
                iconData: Icons.arrow_forward_ios_rounded,
                onPressed: () {
                  widget.pageCtrl.nextPage(
                    duration: const Duration(seconds: 1),
                    curve: Curves.linear,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

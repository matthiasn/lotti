import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/asr_service.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class TranscriptionProgressModalContent extends StatelessWidget {
  const TranscriptionProgressModalContent({super.key});

  @override
  Widget build(BuildContext context) {
    final asrService = getIt<AsrService>();

    return StreamBuilder<(String, TranscriptionStatus)>(
      stream: asrService.progressController.stream,
      builder: (context, snapshot) {
        final text = snapshot.data?.$1 ?? '';
        final status = snapshot.data?.$2;

        if (status == TranscriptionStatus.done) {
          Future<void>.delayed(const Duration(seconds: 3))
              .then((value) => Navigator.of(context).pop());
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: MarkdownBody(data: text),
          ),
        );
      },
    );
  }
}

class TranscriptionProgressModal {
  static SliverWoltModalSheetPage page1(
    BuildContext modalSheetContext,
    TextTheme textTheme,
  ) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      topBarTitle: Text(
        'Transcription Progress',
        style: textTheme.titleSmall,
      ),
      isTopBarLayerAlwaysVisible: true,
      trailingNavBarWidget: IconButton(
        padding: const EdgeInsets.all(WoltModalConfig.pagePadding),
        icon: const Icon(Icons.close),
        onPressed: Navigator.of(modalSheetContext).pop,
      ),
      child: const TranscriptionProgressModalContent(),
    );
  }

  static Future<void> show(BuildContext context) async {
    await WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        final textTheme = Theme.of(context).textTheme;
        return [
          page1(modalSheetContext, textTheme),
        ];
      },
      modalTypeBuilder: (context) {
        final size = MediaQuery.of(context).size.width;
        if (size < WoltModalConfig.pageBreakpoint) {
          return WoltModalType.bottomSheet;
        } else {
          return WoltModalType.dialog;
        }
      },
      onModalDismissedWithBarrierTap: () {
        Navigator.of(context).pop();
      },
      maxDialogWidth: WoltModalConfig.maxDialogWidth,
      minDialogWidth: WoltModalConfig.minDialogWidth,
      minPageHeight: WoltModalConfig.minPageHeight,
      maxPageHeight: WoltModalConfig.maxPageHeight,
    );
  }
}

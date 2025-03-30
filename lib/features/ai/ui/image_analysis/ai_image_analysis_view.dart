import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/image_analysis.dart';
import 'package:lotti/themes/theme.dart';

class AiImageAnalysisView extends ConsumerWidget {
  const AiImageAnalysisView({
    required this.id,
    super.key,
  });

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      aiImageAnalysisControllerProvider(id: id),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 600),
            child: Text(
              summary,
              style: monospaceTextStyleSmall.copyWith(
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

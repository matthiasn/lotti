import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

/// Common interface for FTUE result data used by the dialog.
class FtueResultData {
  const FtueResultData({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.promptsCreated,
    required this.promptsSkipped,
    required this.categoryCreated,
    required this.categoryUpdated,
    this.categoryName,
    this.errors = const [],
  });

  /// Creates from an AlibabaFtueResult
  factory FtueResultData.fromAlibaba(AlibabaFtueResult result) =>
      FtueResultData(
        modelsCreated: result.modelsCreated,
        modelsVerified: result.modelsVerified,
        promptsCreated: result.promptsCreated,
        promptsSkipped: result.promptsSkipped,
        categoryCreated: result.categoryCreated,
        categoryUpdated: result.categoryUpdated,
        categoryName: result.categoryName,
        errors: result.errors,
      );

  /// Creates from a GeminiFtueResult
  factory FtueResultData.fromGemini(GeminiFtueResult result) => FtueResultData(
        modelsCreated: result.modelsCreated,
        modelsVerified: result.modelsVerified,
        promptsCreated: result.promptsCreated,
        promptsSkipped: result.promptsSkipped,
        categoryCreated: result.categoryCreated,
        categoryUpdated: result.categoryUpdated,
        categoryName: result.categoryName,
        errors: result.errors,
      );

  /// Creates from an OpenAiFtueResult
  factory FtueResultData.fromOpenAi(OpenAiFtueResult result) => FtueResultData(
        modelsCreated: result.modelsCreated,
        modelsVerified: result.modelsVerified,
        promptsCreated: result.promptsCreated,
        promptsSkipped: result.promptsSkipped,
        categoryCreated: result.categoryCreated,
        categoryUpdated: result.categoryUpdated,
        categoryName: result.categoryName,
        errors: result.errors,
      );

  /// Creates from a MistralFtueResult
  factory FtueResultData.fromMistral(MistralFtueResult result) =>
      FtueResultData(
        modelsCreated: result.modelsCreated,
        modelsVerified: result.modelsVerified,
        promptsCreated: result.promptsCreated,
        promptsSkipped: result.promptsSkipped,
        categoryCreated: result.categoryCreated,
        categoryUpdated: result.categoryUpdated,
        categoryName: result.categoryName,
        errors: result.errors,
      );

  final int modelsCreated;
  final int modelsVerified;
  final int promptsCreated;
  final int promptsSkipped;
  final bool categoryCreated;
  final bool categoryUpdated;
  final String? categoryName;
  final List<String> errors;
}

/// Dialog shown after FTUE setup completes to display results.
///
/// Shows what was created:
/// - Models created/verified
/// - Prompts created
/// - Category created (if applicable)
/// - Any errors that occurred
class FtueResultDialog extends StatelessWidget {
  const FtueResultDialog({
    required this.result,
    super.key,
  });

  const FtueResultDialog._internal({
    required this.result,
  });

  final FtueResultData result;

  /// Shows the FTUE result dialog for Alibaba.
  static Future<void> showAlibaba(
    BuildContext context, {
    required AlibabaFtueResult result,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FtueResultDialog._internal(
        result: FtueResultData.fromAlibaba(result),
      ),
    );
  }

  /// Shows the FTUE result dialog for Gemini.
  static Future<void> show(
    BuildContext context, {
    required GeminiFtueResult result,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FtueResultDialog._internal(
        result: FtueResultData.fromGemini(result),
      ),
    );
  }

  /// Shows the FTUE result dialog for OpenAI.
  static Future<void> showOpenAi(
    BuildContext context, {
    required OpenAiFtueResult result,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FtueResultDialog._internal(
        result: FtueResultData.fromOpenAi(result),
      ),
    );
  }

  /// Shows the FTUE result dialog for Mistral.
  static Future<void> showMistral(
    BuildContext context, {
    required MistralFtueResult result,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FtueResultDialog._internal(
        result: FtueResultData.fromMistral(result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasErrors = result.errors.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: _buildTitle(context, hasErrors: hasErrors),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultItem(
              context,
              icon: Icons.memory,
              label: 'Models',
              value: _buildModelValue(),
            ),
            const SizedBox(height: 8),
            _buildResultItem(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'Prompts',
              value: _buildPromptValue(),
            ),
            if (result.categoryCreated || result.categoryUpdated) ...[
              const SizedBox(height: 8),
              _buildResultItem(
                context,
                icon: Icons.folder_outlined,
                label: 'Category',
                value: _buildCategoryValue(),
              ),
            ],
            if (hasErrors) ...[
              const SizedBox(height: 16),
              _buildErrorsSection(context),
            ],
          ],
        ),
      ),
      actions: [
        LottiPrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          label: 'Done',
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context, {required bool hasErrors}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasErrors
                ? context.colorScheme.errorContainer
                : context.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            hasErrors ? Icons.warning : Icons.check_circle,
            color: hasErrors
                ? context.colorScheme.onErrorContainer
                : context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            hasErrors ? 'Setup Completed with Warnings' : 'Setup Complete',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _buildModelValue() {
    final parts = <String>[];
    if (result.modelsCreated > 0) {
      parts.add('${result.modelsCreated} created');
    }
    if (result.modelsVerified > 0) {
      parts.add('${result.modelsVerified} verified');
    }
    return parts.isEmpty ? 'None' : parts.join(', ');
  }

  String _buildPromptValue() {
    final parts = <String>[];
    if (result.promptsCreated > 0) {
      parts.add('${result.promptsCreated} created');
    }
    if (result.promptsSkipped > 0) {
      parts.add('${result.promptsSkipped} skipped');
    }
    return parts.isEmpty ? 'None' : parts.join(', ');
  }

  String _buildCategoryValue() {
    final name = result.categoryName ?? 'Test Category';
    if (result.categoryCreated) {
      return '$name (created)';
    }
    if (result.categoryUpdated) {
      return '$name (updated)';
    }
    return name;
  }

  Widget _buildResultItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: context.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Warnings:',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...result.errors.map(
            (e) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                  Expanded(
                    child: Text(
                      e,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

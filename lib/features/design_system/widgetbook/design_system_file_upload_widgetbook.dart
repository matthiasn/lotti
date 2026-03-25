import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/file_uploads/design_system_file_upload.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemFileUploadWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'File upload',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _FileUploadOverviewPage(),
      ),
    ],
  );
}

class _FileUploadOverviewPage extends StatelessWidget {
  const _FileUploadOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _FileUploadSection(
            title: context.messages.designSystemFileUploadDropZoneSectionTitle,
            child: const _DropZoneVariants(),
          ),
          const SizedBox(height: 32),
          _FileUploadSection(
            title: context.messages.designSystemFileUploadItemSectionTitle,
            child: const _FileItemVariants(),
          ),
        ],
      ),
    );
  }
}

class _FileUploadSection extends StatelessWidget {
  const _FileUploadSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _DropZoneVariants extends StatelessWidget {
  const _DropZoneVariants();

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.designSystemFileUploadDefaultLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DesignSystemFileUploadDropZone(
            clickToUploadLabel: messages.designSystemFileUploadClickLabel,
            dragAndDropLabel: messages.designSystemFileUploadDragLabel,
            hintText: messages.designSystemFileUploadHintText,
            onTap: () {},
          ),

          const SizedBox(height: 24),

          Text(
            messages.designSystemFileUploadHoverLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DesignSystemFileUploadDropZone(
            clickToUploadLabel: messages.designSystemFileUploadClickLabel,
            dragAndDropLabel: messages.designSystemFileUploadDragLabel,
            hintText: messages.designSystemFileUploadHintText,
            forcedState: DesignSystemFileUploadDropZoneVisualState.hover,
            onTap: () {},
          ),

          const SizedBox(height: 24),

          Text(
            messages.designSystemDisabledLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DesignSystemFileUploadDropZone(
            clickToUploadLabel: messages.designSystemFileUploadClickLabel,
            dragAndDropLabel: messages.designSystemFileUploadDragLabel,
            hintText: messages.designSystemFileUploadHintText,
            forcedState: DesignSystemFileUploadDropZoneVisualState.disabled,
          ),
        ],
      ),
    );
  }
}

class _FileItemVariants extends StatelessWidget {
  const _FileItemVariants();

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    const sampleFileName = 'Game_of_throne.png';
    const sampleFileSize = '200 KB';

    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.designSystemFileUploadUploadingLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DesignSystemFileUploadItem(
            fileName: sampleFileName,
            fileSize: sampleFileSize,
            status: DesignSystemFileUploadItemStatus.uploading,
            progress: 0.2,
            onCancel: () {},
          ),

          const SizedBox(height: 16),

          Text(
            messages.designSystemFileUploadCompleteLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const DesignSystemFileUploadItem(
            fileName: sampleFileName,
            fileSize: sampleFileSize,
            status: DesignSystemFileUploadItemStatus.complete,
            progress: 1,
          ),

          const SizedBox(height: 16),

          Text(
            messages.designSystemFileUploadErrorLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DesignSystemFileUploadItem(
            fileName: sampleFileName,
            fileSize: sampleFileSize,
            status: DesignSystemFileUploadItemStatus.error,
            errorLabel: messages.designSystemFileUploadFailedText,
            retryLabel: messages.designSystemFileUploadRetryLabel,
            onRetry: () {},
          ),
        ],
      ),
    );
  }
}

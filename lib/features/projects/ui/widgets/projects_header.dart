import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class ProjectsHeader extends StatelessWidget {
  const ProjectsHeader({
    required this.title,
    this.query = '',
    this.searchEnabled = true,
    this.onSearchChanged,
    this.onSearchCleared,
    this.onSearchPressed,
    this.titleTrailing,
    this.searchTrailing,
    this.centerTitle = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.titleBottomSpacing = 24,
    super.key,
  });

  final String title;
  final String query;
  final bool searchEnabled;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchCleared;
  final ValueChanged<String>? onSearchPressed;
  final Widget? titleTrailing;
  final Widget? searchTrailing;
  final bool centerTitle;
  final EdgeInsets padding;
  final double titleBottomSpacing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final compactTitleStyle = tokens.typography.styles.heading.heading3;
    final defaultTitleStyle = tokens.typography.styles.heading.heading2;
    final titleStyle = isCompact ? compactTitleStyle : defaultTitleStyle;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (centerTitle && titleTrailing == null)
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.heading.heading1.copyWith(
                  color: ShowcasePalette.highText(context),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                    style: titleStyle.copyWith(
                      color: ShowcasePalette.highText(context),
                    ),
                  ),
                ),
                if (titleTrailing != null) ...[
                  const SizedBox(width: 12),
                  titleTrailing!,
                ],
              ],
            ),
          SizedBox(height: titleBottomSpacing),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: DesignSystemSearch(
                    hintText: context.messages.projectShowcaseSearchHint,
                    initialText: query,
                    enabled: searchEnabled,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                    onSearchPressed: onSearchPressed,
                  ),
                ),
              ),
              if (searchTrailing != null) ...[
                const SizedBox(width: 12),
                searchTrailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

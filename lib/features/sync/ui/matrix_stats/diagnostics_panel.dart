import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_typography.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class DiagnosticsPanel extends StatefulWidget {
  const DiagnosticsPanel({
    required this.fetchDiagnostics,
    super.key,
  });

  final Future<String> Function() fetchDiagnostics;

  @override
  State<DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<DiagnosticsPanel> {
  bool _expanded = false;
  Future<String>? _future;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    return ExpansionTile(
      title: Text(
        messages.matrixStatsDiagnostics,
        style: metricsGroupHeading(tokens),
      ),
      onExpansionChanged: (open) {
        setState(() {
          _expanded = open;
          if (_expanded) {
            _future ??= widget.fetchDiagnostics();
          }
        });
      },
      children: [
        if (_expanded)
          FutureBuilder<String>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                // The panel-loading idiom the sibling sync surfaces use
                // (`sync_devices_list.dart`, `add_device_page.dart`): the
                // full-size spinner centred, with room around it. A bare
                // `step3` inset would leave the 48pt default hugging the
                // left edge of the disclosure.
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: tokens.spacing.step6,
                    ),
                    child: const DesignSystemSpinner(),
                  ),
                );
              }
              final txt = snap.data ?? '';
              final lines = txt
                  .split('\n')
                  .where((l) => l.contains('='))
                  .toList();
              final diag = <String, String>{};
              for (final l in lines) {
                final i = l.indexOf('=');
                if (i > 0) {
                  diag[l.substring(0, i)] = l.substring(i + 1);
                }
              }
              final dbMissingBase = diag['dbMissingBase'] ?? '0';
              final ignoredCount =
                  int.tryParse(diag['lastIgnoredCount'] ?? '0') ?? 0;
              final bodyStyle = tokens.typography.styles.body.bodySmall
                  .copyWith(color: tokens.colors.text.mediumEmphasis);
              // Prefetch details removed.
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                messages.matrixStatsDbMissingBaseValue(
                                  dbMissingBase,
                                ),
                                style: bodyStyle,
                              ),
                            ],
                          ),
                        ),
                        DesignSystemIconAction(
                          icon: Icons.refresh_rounded,
                          tooltip:
                              messages.matrixStatsRefreshDiagnosticsTooltip,
                          onPressed: () => setState(() {
                            _future = widget.fetchDiagnostics();
                          }),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    if (ignoredCount > 0) ...[
                      Text(messages.matrixStatsLastIgnored, style: bodyStyle),
                      for (var i = 1; i <= ignoredCount; i++)
                        Text(diag['lastIgnored.$i'] ?? '', style: bodyStyle),
                      SizedBox(height: tokens.spacing.step3),
                    ],
                    // Prefetch details removed.
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

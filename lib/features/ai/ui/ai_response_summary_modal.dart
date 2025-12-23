import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher.dart';

class AiResponseSummaryModalContent extends StatelessWidget {
  const AiResponseSummaryModalContent(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

  static Future<void> _handleLinkTap(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool bold = false,
    bool isNumeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          if (isNumeric)
            SizedBox(
              width: 80,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                value,
                style:
                    bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    if (duration.inMinutes >= 1) {
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      return '${mins}m ${secs}s';
    } else if (duration.inSeconds >= 1) {
      final secs = duration.inSeconds;
      final ms = duration.inMilliseconds % 1000;
      return '$secs.${(ms / 100).floor()}s';
    } else {
      return '${duration.inMilliseconds}ms';
    }
  }

  bool get _hasUsageData =>
      aiResponse.data.inputTokens != null ||
      aiResponse.data.outputTokens != null ||
      aiResponse.data.durationMs != null;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 10,
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      height: 600,
      child: DefaultTabController(
        length: 4,
        initialIndex: 3,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            title: const TabBar(
              tabs: [
                Tab(text: 'Setup'),
                Tab(text: 'Input'),
                Tab(text: 'Thoughts'),
                Tab(text: 'Response'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Configuration',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Model', aiResponse.data.model),
                        _buildInfoRow(
                          'Temperature',
                          aiResponse.data.temperature?.toString() ?? 'N/A',
                        ),
                        if (_hasUsageData) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Performance',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (aiResponse.data.durationMs != null)
                            _buildInfoRow(
                              'Duration',
                              _formatDuration(aiResponse.data.durationMs!),
                              isNumeric: true,
                            ),
                          if (aiResponse.data.inputTokens != null ||
                              aiResponse.data.outputTokens != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Token Usage',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            if (aiResponse.data.inputTokens != null)
                              _buildInfoRow(
                                'Input',
                                '${aiResponse.data.inputTokens}',
                                isNumeric: true,
                              ),
                            if (aiResponse.data.outputTokens != null)
                              _buildInfoRow(
                                'Output',
                                '${aiResponse.data.outputTokens}',
                                isNumeric: true,
                              ),
                            if (aiResponse.data.thoughtsTokens != null)
                              _buildInfoRow(
                                'Thoughts',
                                '${aiResponse.data.thoughtsTokens}',
                                isNumeric: true,
                              ),
                            _buildInfoRow(
                              'Total',
                              '${(aiResponse.data.inputTokens ?? 0) + (aiResponse.data.outputTokens ?? 0)}',
                              bold: true,
                              isNumeric: true,
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'System Prompt',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DefaultTextStyle(
                          style: TextStyle(color: Colors.grey[400]),
                          child: GptMarkdown(aiResponse.data.systemMessage),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: GestureDetector(
                    onDoubleTap: () {
                      final clipboard = SystemClipboard.instance;
                      final item = DataWriterItem();
                      final data = aiResponse.data.prompt;
                      item.add(Formats.plainText(data));
                      clipboard?.write([item]);
                    },
                    child: SelectionArea(
                      child: GptMarkdown(aiResponse.data.prompt),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: SelectionArea(
                    child: GptMarkdown(aiResponse.data.thoughts),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: SelectionArea(
                    child: GptMarkdown(
                      aiResponse.data.response,
                      onLinkTap: _handleLinkTap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

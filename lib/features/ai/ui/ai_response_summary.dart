import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/utils/modals.dart';

class AiResponseSummary extends StatelessWidget {
  const AiResponseSummary(this.aiResponse, {super.key});

  final AiResponseEntry aiResponse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: GestureDetector(
        onDoubleTap: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            builder: (BuildContext _) {
              return AiResponseSummaryModalContent(aiResponse);
            },
          );
        },
        child: SelectionArea(
          child: GptMarkdown(aiResponse.data.response),
        ),
      ),
    );
  }
}

class AiResponseSummaryModalContent extends StatelessWidget {
  const AiResponseSummaryModalContent(
    this.aiResponse, {
    super.key,
  });

  final AiResponseEntry aiResponse;

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
                        Text('Model: ${aiResponse.data.model}'),
                        Text('Temperature: ${aiResponse.data.temperature}'),
                        const SizedBox(height: 10),
                        GptMarkdown(aiResponse.data.systemMessage),
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: SelectionArea(
                    child: GptMarkdown(aiResponse.data.prompt),
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
                  child: Column(
                    children: [
                      SelectionArea(
                        child: GptMarkdown(aiResponse.data.response),
                      ),
                      NewChecklistItemWidget(
                          response: aiResponse.data.response),
                    ],
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

class NewChecklistItemWidget extends ConsumerWidget {
  const NewChecklistItemWidget({
    required this.response,
    super.key,
  });

  final String response;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final exp = RegExp(
      r'TODO:\s(.+)',
      multiLine: true,
    );

    final checklistItems = exp
        .allMatches(response)
        .map((e) {
          final title = e.group(1);
          if (title != null) {
            return ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: [],
            );
          }
        })
        .nonNulls
        .toList();

    return Column(
      children: [
        ...checklistItems.map(
          (checklistItem) => ChecklistItemWidget(
            title: checklistItem.title,
            isChecked: checklistItem.isChecked,
            onChanged: (checked) {},
          ),
        ),
      ],
    );
  }
}

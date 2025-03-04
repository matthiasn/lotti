import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/modals.dart';

class AiResponseSummary extends StatelessWidget {
  const AiResponseSummary(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: GestureDetector(
        onDoubleTap: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            builder: (BuildContext _) {
              return AiResponseSummaryModalContent(
                aiResponse,
                linkedFromId: linkedFromId,
              );
            },
          );
        },
        child: ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              stops: [0.3, 1.0],
              colors: [
                Colors.black,
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTRB(
                0,
                0,
                rect.width,
                rect.height,
              ),
            );
          },
          blendMode: BlendMode.dstIn,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SelectionArea(
              child: GptMarkdown(aiResponse.data.response),
            ),
          ),
        ),
      ),
    );
  }
}

class AiResponseSummaryModalContent extends StatelessWidget {
  const AiResponseSummaryModalContent(
    this.aiResponse, {
    required this.linkedFromId,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;

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
                  child: SelectionArea(
                    child: GptMarkdown(aiResponse.data.response),
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

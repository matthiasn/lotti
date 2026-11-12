import 'package:lotti/features/front_agent/model/front_pull_requests.dart';

/// Picks, of [candidates], the keys of those about [topic], most relevant
/// first: at most [frontPullRequestsFoundMax], none when none is.
typedef FrontPullRequestFilter =
    Future<List<String>> Function(
      String topic,
      List<FrontFoundPullRequest> candidates,
    );

/// Asks a model [prompt] under [systemMessage], once and without tools;
/// its answer, or null when it gave none.
typedef FrontOneOffAsk =
    Future<String?> Function({
      required String systemMessage,
      required String prompt,
    });

/// The system message of the filter call: a task of its own, outside her
/// conversation, so a month of pull requests never enters it.
const String frontPullRequestFilterSystemMessage =
    'You pick, from a list of pull requests, the ones about a topic. A pull '
    'request is about it when its title, its summary or the title of its '
    'task says it worked on that topic, in whatever words. Answer with the '
    'ids of the pull requests about it, most relevant first, one per line, '
    'at most $frontPullRequestsFoundMax, and nothing else. Answer NONE when '
    'no pull request is about it.';

/// The filter call's prompt: the topic, then each candidate on one line.
String frontPullRequestFilterPrompt(
  String topic,
  List<FrontFoundPullRequest> candidates,
) => [
  'Topic: $topic',
  '',
  'Pull requests, each as id | title | opened | merged | task | summary:',
  for (final pr in candidates) '- ${pr.render()}',
].join('\n');

final RegExp _key = RegExp(r'[\w.-]+/[\w.-]+#\d+');

/// The keys of [keys] that [answer] names, in its order, each once, at most
/// [frontPullRequestsFoundMax]: a key the model made up is never kept.
List<String> parseFrontPullRequestFilter(String answer, Set<String> keys) => [
  ...{
    for (final match in _key.allMatches(answer))
      if (keys.contains(match.group(0))) match.group(0)!,
  },
].take(frontPullRequestsFoundMax).toList();

/// The filter that runs as one isolated call through [ask]: the candidates
/// in, the keys of those about the topic out. A failed call throws; no
/// answer keeps none.
FrontPullRequestFilter frontPullRequestFilter(FrontOneOffAsk ask) =>
    (topic, candidates) async {
      final answer = await ask(
        systemMessage: frontPullRequestFilterSystemMessage,
        prompt: frontPullRequestFilterPrompt(topic, candidates),
      );
      return parseFrontPullRequestFilter(answer ?? '', {
        for (final pr in candidates) pr.key,
      });
    };

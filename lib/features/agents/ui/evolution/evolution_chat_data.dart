import 'package:genui/genui.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';

/// Holds the full state for an active evolution chat session.
class EvolutionChatData {
  const EvolutionChatData({
    required this.messages,
    this.sessionId,
    this.isWaiting = false,
    this.processor,
    this.categoryRatings = const {},
    this.lastSurfacedProposalKey,
  });

  final String? sessionId;
  final List<EvolutionChatMessage> messages;
  final bool isWaiting;

  /// The GenUI message processor, available after session start.
  /// Used by [Surface] widgets to render dynamic content.
  final SurfaceController? processor;
  final Map<String, int> categoryRatings;
  final String? lastSurfacedProposalKey;

  EvolutionChatData copyWith({
    String? Function()? sessionId,
    List<EvolutionChatMessage>? messages,
    bool? isWaiting,
    SurfaceController? Function()? processor,
    Map<String, int>? categoryRatings,
    String? Function()? lastSurfacedProposalKey,
  }) {
    return EvolutionChatData(
      sessionId: sessionId != null ? sessionId() : this.sessionId,
      messages: messages ?? this.messages,
      isWaiting: isWaiting ?? this.isWaiting,
      processor: processor != null ? processor() : this.processor,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      lastSurfacedProposalKey: lastSurfacedProposalKey != null
          ? lastSurfacedProposalKey()
          : this.lastSurfacedProposalKey,
    );
  }
}

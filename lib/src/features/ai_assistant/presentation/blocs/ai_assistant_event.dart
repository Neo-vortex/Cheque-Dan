part of 'ai_assistant_bloc.dart';

abstract class AiAssistantEvent extends Equatable {
  const AiAssistantEvent();
  @override
  List<Object?> get props => [];
}

class LoadModelEvent extends AiAssistantEvent {
  const LoadModelEvent();
}

class ConfirmLoadModelEvent extends AiAssistantEvent {
  const ConfirmLoadModelEvent();
}

class SendAiMessageEvent extends AiAssistantEvent {
  final String text;
  const SendAiMessageEvent(this.text);
  @override
  List<Object?> get props => [text];
}

class ExecuteAiCommandEvent extends AiAssistantEvent {
  final String messageId;
  const ExecuteAiCommandEvent(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class CancelAiCommandEvent extends AiAssistantEvent {
  final String messageId;
  const CancelAiCommandEvent(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class ResetAiConversationEvent extends AiAssistantEvent {
  const ResetAiConversationEvent();
}

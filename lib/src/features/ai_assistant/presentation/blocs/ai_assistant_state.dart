part of 'ai_assistant_bloc.dart';

abstract class AiAssistantState extends Equatable {
  final List<AiMessage> messages;
  const AiAssistantState({required this.messages});
  @override
  List<Object?> get props => [messages];
}

class AiAssistantInitial extends AiAssistantState {
  const AiAssistantInitial() : super(messages: const []);
}

class AiAssistantHardwareWarning extends AiAssistantState {
  final int ramGb;
  final int cpuCores;
  const AiAssistantHardwareWarning({required this.ramGb, required this.cpuCores})
      : super(messages: const []);
  @override
  List<Object?> get props => [ramGb, cpuCores, messages];
}

class AiAssistantLoading extends AiAssistantState {
  final String message;
  const AiAssistantLoading({required this.message}) : super(messages: const []);
  @override
  List<Object?> get props => [message, messages];
}

class AiAssistantReady extends AiAssistantState {
  const AiAssistantReady({required super.messages});
}

class AiAssistantExecuting extends AiAssistantState {
  const AiAssistantExecuting({required super.messages});
}

/// Emitted after a command runs — carries a flag so the screen can
/// trigger a ChequeBloc refresh.
class AiAssistantCommandDone extends AiAssistantState {
  final bool success;
  final String message;
  final bool needsUiRefresh; // true when cheques/cheque_books were mutated
  const AiAssistantCommandDone({
    required super.messages,
    required this.success,
    required this.message,
    this.needsUiRefresh = false,
  });
  @override
  List<Object?> get props => [success, message, needsUiRefresh, messages];
}

class AiAssistantError extends AiAssistantState {
  final String error;
  const AiAssistantError({required this.error, required super.messages});
  @override
  List<Object?> get props => [error, messages];
}

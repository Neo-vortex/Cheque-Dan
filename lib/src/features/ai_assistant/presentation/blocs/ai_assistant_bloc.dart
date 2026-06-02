import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../data/ai_service.dart';
import '../../models/ai_message.dart';

part 'ai_assistant_event.dart';
part 'ai_assistant_state.dart';

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final AiService _service;
  final _uuid = const Uuid();
  List<AiMessage> _messages = [];

  static const int _minRamGb = 6;
  static const int _minCpuCores = 8;

  AiAssistantBloc({AiService? service})
      : _service = service ?? AiService.instance,
        super(const AiAssistantInitial()) {
    on<LoadModelEvent>(_onLoadModel);
    on<ConfirmLoadModelEvent>(_onConfirmLoad);
    on<SendAiMessageEvent>(_onSendMessage);
    on<ExecuteAiCommandEvent>(_onExecuteCommand);
    on<CancelAiCommandEvent>(_onCancelCommand);
    on<ResetAiConversationEvent>(_onReset);
  }

  // ── Hardware detection ──────────────────────────────────────────────────────

  int _detectRamGb() {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        final meminfo = File('/proc/meminfo').readAsStringSync();
        final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
        if (match != null) {
          return (int.parse(match.group(1)!) / 1024 / 1024).round();
        }
      }
    } catch (_) {}
    return 0;
  }

  int _detectCpuCores() {
    try { return Platform.numberOfProcessors; } catch (_) { return 0; }
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onLoadModel(LoadModelEvent event, Emitter<AiAssistantState> emit) async {
    if (_service.isReady) { emit(AiAssistantReady(messages: _messages)); return; }
    final ram = _detectRamGb();
    final cores = _detectCpuCores();
    if ((ram > 0 && ram < _minRamGb) || (cores > 0 && cores < _minCpuCores)) {
      emit(AiAssistantHardwareWarning(ramGb: ram, cpuCores: cores));
    } else {
      add(const ConfirmLoadModelEvent());
    }
  }

  Future<void> _onConfirmLoad(ConfirmLoadModelEvent event, Emitter<AiAssistantState> emit) async {
    emit(const AiAssistantLoading(message: 'در حال بارگذاری مدل هوش مصنوعی…'));
    try {
      await _service.initialize();
      emit(AiAssistantReady(messages: _messages));
    } catch (e) {
      emit(AiAssistantError(error: 'خطا در راه‌اندازی: $e', messages: _messages));
    }
  }

  Future<void> _onSendMessage(SendAiMessageEvent event, Emitter<AiAssistantState> emit) async {
    if (!_service.isReady) return;

    final userMsg = AiMessage(
      id: _uuid.v4(), role: AiMessageRole.user,
      text: event.text, timestamp: DateTime.now(),
    );
    final loadingMsg = AiMessage(
      id: _uuid.v4(), role: AiMessageRole.assistant,
      text: '', timestamp: DateTime.now(), isLoading: true,
    );
    _messages = [..._messages, userMsg, loadingMsg];
    emit(AiAssistantReady(messages: _messages));

    try {
      var result = await _service.sendMessage(event.text);

      if (result.type == AiResultType.query) {
        result = await _service.executeQuery(result);
      }
      if (result.type == AiResultType.analytical) {
        result = await _service.executeAnalytical(result);
      }
      if (result.type == AiResultType.command) {
        result = await _service.previewCommand(result);
      }

      final assistantMsg = loadingMsg.copyWith(
        text: result.explanation, result: result, isLoading: false,
      );
      _messages = _messages.map((m) => m.id == loadingMsg.id ? assistantMsg : m).toList();
      emit(AiAssistantReady(messages: _messages));
    } catch (e) {
      final errorMsg = loadingMsg.copyWith(
        text: 'مشکلی پیش اومد، دوباره امتحان کن.', isLoading: false,
      );
      _messages = _messages.map((m) => m.id == loadingMsg.id ? errorMsg : m).toList();
      emit(AiAssistantReady(messages: _messages));
    }
  }

  Future<void> _onExecuteCommand(ExecuteAiCommandEvent event, Emitter<AiAssistantState> emit) async {
    final msgIndex = _messages.indexWhere((m) => m.id == event.messageId);
    if (msgIndex < 0) return;
    final msg = _messages[msgIndex];
    if (msg.result == null) return;

    emit(AiAssistantExecuting(messages: _messages));

    try {
      final executed = await _service.executeCommand(msg.result!);
      final updated = msg.copyWith(result: executed);
      _messages = List.of(_messages)..[msgIndex] = updated;

      // Detect if the command mutated cheques or cheque_books so UI can refresh
      final sql = (msg.result!.executeSql ?? '').toLowerCase();
      final touchesCheques = sql.contains('cheques') || sql.contains('cheque_books');

      emit(AiAssistantCommandDone(
        messages: _messages,
        success: executed.executed == true,
        message: executed.executed == true
            ? 'عملیات با موفقیت انجام شد ✓'
            : (executed.executionError ?? 'خطا در اجرا'),
        needsUiRefresh: executed.executed == true && touchesCheques,
      ));
    } catch (e) {
      emit(AiAssistantCommandDone(
        messages: _messages, success: false,
        message: 'مشکلی پیش اومد، دوباره امتحان کن.',
      ));
    }
  }

  Future<void> _onCancelCommand(CancelAiCommandEvent event, Emitter<AiAssistantState> emit) async {
    final msgIndex = _messages.indexWhere((m) => m.id == event.messageId);
    if (msgIndex >= 0) {
      final msg = _messages[msgIndex];
      if (msg.result != null) {
        _messages = List.of(_messages)
          ..[msgIndex] = msg.copyWith(result: msg.result!.copyWith(executed: false));
      }
    }
    emit(AiAssistantReady(messages: _messages));
  }

  Future<void> _onReset(ResetAiConversationEvent event, Emitter<AiAssistantState> emit) async {
    _messages = [];
    await _service.resetConversation();
    emit(AiAssistantReady(messages: _messages));
  }
}

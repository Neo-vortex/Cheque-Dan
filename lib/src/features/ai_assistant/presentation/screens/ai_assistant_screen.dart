import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/ai_message.dart';
import '../blocs/ai_assistant_bloc.dart';
import '../../../cheques/presentation/blocs/cheque_bloc.dart';
import '../widgets/ai_message_bubble.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;
    _inputCtrl.clear();
    setState(() => _isSending = true);
    context.read<AiAssistantBloc>().add(SendAiMessageEvent(trimmed));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Shows the hardware-warning bottom sheet and waits for user decision.
  void _showHardwareWarning(
      BuildContext context, AiAssistantHardwareWarning state) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HardwareWarningSheet(
        ramGb: state.ramGb,
        cpuCores: state.cpuCores,
        onConfirm: () {
          Navigator.of(context).pop();
          context
              .read<AiAssistantBloc>()
              .add(const ConfirmLoadModelEvent());
        },
        onCancel: () {
          Navigator.of(context).pop();
          // Stay on idle screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF0F4F3),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('دستیار هوشمند'),
          ],
        ),
        actions: [
          BlocBuilder<AiAssistantBloc, AiAssistantState>(
            builder: (context, state) {
              if (state is AiAssistantReady && state.messages.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: 'شروع مجدد گفتگو',
                  onPressed: () => context
                      .read<AiAssistantBloc>()
                      .add(const ResetAiConversationEvent()),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<AiAssistantBloc, AiAssistantState>(
        listener: (context, state) {
          if (state is AiAssistantReady || state is AiAssistantCommandDone) {
            setState(() => _isSending = false);
            _scrollToBottom();
          }
          if (state is AiAssistantCommandDone) {
            // Refresh cheque list when cheques/cheque_books were mutated
            if (state.needsUiRefresh) {
              try {
                context.read<ChequeBloc>().add(const LoadChequesEvent());
              } catch (_) {}
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor:
                    state.success ? AppColors.cleared : AppColors.returned,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          if (state is AiAssistantHardwareWarning) {
            _showHardwareWarning(context, state);
          }
        },
        builder: (context, state) {
          // ── Splash / loading ────────────────────────────────────────────
          if (state is AiAssistantLoading) {
            return _ModelLoadingSplash(message: state.message);
          }

          // ── Hard error (load failed, no messages yet) ───────────────────
          if (state is AiAssistantError && state.messages.isEmpty) {
            return _ErrorView(
              error: state.error,
              onRetry: () => context
                  .read<AiAssistantBloc>()
                  .add(const LoadModelEvent()),
            );
          }

          // ── Idle: model not loaded yet ──────────────────────────────────
          if (state is AiAssistantInitial ||
              state is AiAssistantHardwareWarning) {
            return _IdleView(isDark: isDark);
          }

          // ── Chat UI ─────────────────────────────────────────────────────
          final messages =
              state is AiAssistantInitial ? <AiMessage>[] : state.messages;
          final isExecuting = state is AiAssistantExecuting;

          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? _WelcomeView(
                        onSuggestion: _sendMessage,
                        isDark: isDark,
                      )
                    : _ChatList(
                        messages: messages,
                        scrollCtrl: _scrollCtrl,
                        isExecuting: isExecuting,
                        onExecuteCommand: (id) => context
                            .read<AiAssistantBloc>()
                            .add(ExecuteAiCommandEvent(id)),
                        onCancelCommand: (id) => context
                            .read<AiAssistantBloc>()
                            .add(CancelAiCommandEvent(id)),
                      ),
              ),
              _InputBar(
                controller: _inputCtrl,
                focus: _inputFocus,
                isSending: _isSending,
                isDark: isDark,
                onSend: _sendMessage,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Idle view: shown before model is loaded
// ──────────────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final bool isDark;
  const _IdleView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'دستیار هوشمند چک دان',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'مدل هوش مصنوعی روی دستگاه شما اجرا می‌شود.\nبرای شروع، مدل را بارگذاری کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            // Requirement note
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'پیشنهاد: حداقل ۶ گیگ RAM و ۸ هسته CPU',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context
                  .read<AiAssistantBloc>()
                  .add(const LoadModelEvent()),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('بارگذاری مدل'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Hardware warning bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _HardwareWarningSheet extends StatelessWidget {
  final int ramGb;
  final int cpuCores;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _HardwareWarningSheet({
    required this.ramGb,
    required this.cpuCores,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ramLow = ramGb > 0 && ramGb < 6;
    final coresLow = cpuCores > 0 && cpuCores < 8;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.warning_amber_rounded,
              size: 52, color: Colors.orange),
          const SizedBox(height: 12),
          const Text(
            'هشدار: سخت‌افزار ضعیف',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'دستگاه شما ممکن است برای اجرای مدل هوش مصنوعی کافی نباشد:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (ramLow)
            _WarningRow(
              icon: Icons.memory,
              label: 'RAM شناسایی‌شده',
              value: '$ramGb گیگابایت',
              note: 'حداقل پیشنهادی: ۶ گیگابایت',
            ),
          if (coresLow)
            _WarningRow(
              icon: Icons.developer_board,
              label: 'هسته‌های CPU',
              value: '$cpuCores هسته',
              note: 'حداقل پیشنهادی: ۸ هسته',
            ),
          const SizedBox(height: 8),
          Text(
            'ادامه دادن ممکن است باعث کندی یا کرش شود.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ادامه می‌دهم'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;

  const _WarningRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('$value  •  $note',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Model loading splash (full-screen)
// ──────────────────────────────────────────────────────────────────────────────

class _ModelLoadingSplash extends StatelessWidget {
  final String message;
  const _ModelLoadingSplash({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: Color(0x22000000),
              minHeight: 5,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'این ممکن است چند لحظه طول بکشد…',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.returned),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final ValueChanged<String> onSuggestion;
  final bool isDark;

  const _WelcomeView({required this.onSuggestion, required this.isDark});

  static const _suggestions = [
    'چند تا چک این ماه سررسید دارم؟',
    'مجموع چک‌های صادره من چقدر است؟',
    'چک‌های بانک ملت که هنوز وصول نشده‌اند',
    'چک‌های برگشت خورده را نشان بده',
    'مجموع دریافتی‌های این ماه چقدر است؟',
    'دسته چک‌های فعال را نشان بده',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'سلام! دستیار هوشمند چک دان',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'از من درباره چک‌ها، دسته چک‌ها، مبالغ\nو سررسیدها بپرسید.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'پیشنهادها',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => _SuggestionChip(
                      text: s,
                      isDark: isDark,
                      onTap: () => onSuggestion(s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.text,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 13, color: AppColors.secondary),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final List<AiMessage> messages;
  final ScrollController scrollCtrl;
  final bool isExecuting;
  final ValueChanged<String> onExecuteCommand;
  final ValueChanged<String> onCancelCommand;

  const _ChatList({
    required this.messages,
    required this.scrollCtrl,
    required this.isExecuting,
    required this.onExecuteCommand,
    required this.onCancelCommand,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return AiMessageBubble(
          message: msg,
          isExecuting: isExecuting && msg.role == AiMessageRole.assistant,
          onExecuteCommand: msg.result?.type == AiResultType.command
              ? () => onExecuteCommand(msg.id)
              : null,
          onCancelCommand: msg.result?.type == AiResultType.command
              ? () => onCancelCommand(msg.id)
              : null,
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool isSending;
  final bool isDark;
  final ValueChanged<String> onSend;

  const _InputBar({
    required this.controller,
    required this.focus,
    required this.isSending,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                textDirection: TextDirection.rtl,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'سوال یا دستور خود را بنویسید…',
                  hintStyle: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextHint : AppColors.textHint,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: isSending
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isSending
                    ? AppColors.primaryLight.withOpacity(0.3)
                    : null,
                borderRadius: BorderRadius.circular(23),
                boxShadow: isSending
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: IconButton(
                onPressed: isSending ? null : () => onSend(controller.text),
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

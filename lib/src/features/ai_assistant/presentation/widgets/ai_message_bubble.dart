import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/ai_message.dart';
import 'ai_result_table.dart';

/// Renders a single chat bubble for the AI assistant screen
class AiMessageBubble extends StatelessWidget {
  final AiMessage message;
  final VoidCallback? onExecuteCommand;
  final VoidCallback? onCancelCommand;
  final bool isExecuting;

  const AiMessageBubble({
    super.key,
    required this.message,
    this.onExecuteCommand,
    this.onCancelCommand,
    this.isExecuting = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        right: isUser ? 48 : 0,
        left: isUser ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Avatar + bubble row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _AiAvatar(isDark: isDark),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Message bubble
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkSurface
                                : AppColors.surface),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: isUser
                            ? null
                            : Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: message.isLoading
                          ? _ThinkingIndicator(isDark: isDark)
                          : Text(
                              message.text.isEmpty && message.result != null
                                  ? message.result!.explanation
                                  : message.text,
                              style: TextStyle(
                                fontSize: 14,
                                color: isUser
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary),
                                height: 1.5,
                              ),
                            ),
                    ),

                    // Result area (query rows or command preview)
                    if (!message.isLoading && message.result != null) ...[
                      const SizedBox(height: 8),
                      _ResultArea(
                        result: message.result!,
                        isDark: isDark,
                        onExecute: onExecuteCommand,
                        onCancel: onCancelCommand,
                        isExecuting: isExecuting,
                      ),
                    ],
                  ],
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              right: isUser ? 0 : 40,
              left: isUser ? 0 : 40,
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color:
                    isDark ? AppColors.darkTextHint : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  final bool isDark;
  const _AiAvatar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ThinkingIndicator extends StatefulWidget {
  final bool isDark;
  const _ThinkingIndicator({required this.isDark});

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'در حال تفکر',
          style: TextStyle(
            fontSize: 13,
            color: widget.isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Row(
            children: List.generate(3, (i) {
              final delay = i * 0.3;
              final opacity = (((_anim.value + delay) % 1.0) * 2 - 1).abs();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity.clamp(0.2, 1.0),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ResultArea extends StatelessWidget {
  final AiQueryResult result;
  final bool isDark;
  final VoidCallback? onExecute;
  final VoidCallback? onCancel;
  final bool isExecuting;

  const _ResultArea({
    required this.result,
    required this.isDark,
    this.onExecute,
    this.onCancel,
    this.isExecuting = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (result.type) {
      case AiResultType.query:
        return _QueryResultArea(result: result, isDark: isDark);
      case AiResultType.analytical:
        return _AnalyticalResultArea(result: result, isDark: isDark);
      case AiResultType.command:
        return _CommandPreviewArea(
          result: result,
          isDark: isDark,
          onExecute: onExecute,
          onCancel: onCancel,
          isExecuting: isExecuting,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _QueryResultArea extends StatelessWidget {
  final AiQueryResult result;
  final bool isDark;

  const _QueryResultArea({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (result.executionError != null) {
      return _ErrorChip(error: result.executionError!, isDark: isDark);
    }

    if (result.rows == null) return const SizedBox.shrink();

    return AiResultTable(
      rows: result.rows!,
      resultCategory: result.resultCategory,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────


// ──────────────────────────────────────────────────────────────────────────────

class _AnalyticalResultArea extends StatelessWidget {
  final AiQueryResult result;
  final bool isDark;
  const _AnalyticalResultArea({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final queries = result.analyticalQueries;
    if (queries == null || queries.isEmpty) return const SizedBox.shrink();
    return AiAnalyticalResult(queries: queries, isDark: isDark);
  }
}

class _CommandPreviewArea extends StatelessWidget {
  final AiQueryResult result;
  final bool isDark;
  final VoidCallback? onExecute;
  final VoidCallback? onCancel;
  final bool isExecuting;

  const _CommandPreviewArea({
    required this.result,
    required this.isDark,
    this.onExecute,
    this.onCancel,
    this.isExecuting = false,
  });

  @override
  Widget build(BuildContext context) {
    final alreadyDone = result.executed != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.executed == true
              ? AppColors.cleared.withOpacity(0.4)
              : result.warning != null
                  ? AppColors.returned.withOpacity(0.3)
                  : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                alreadyDone
                    ? (result.executed == true
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined)
                    : Icons.preview_outlined,
                size: 16,
                color: alreadyDone
                    ? (result.executed == true
                        ? AppColors.cleared
                        : AppColors.returned)
                    : AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                alreadyDone
                    ? (result.executed == true
                        ? 'اجرا شد'
                        : 'لغو شد')
                    : 'پیش‌نمایش تغییرات',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: alreadyDone
                      ? (result.executed == true
                          ? AppColors.cleared
                          : AppColors.returned)
                      : AppColors.secondary,
                ),
              ),
              if (!alreadyDone && result.affectedRows != null) ...[
                const SizedBox(width: 6),
                Text(
                  '(${result.affectedRows} ردیف)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          // Warning
          if (result.warning != null && !alreadyDone) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.returned.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 14, color: AppColors.returned),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.warning!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.returned,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Preview rows
          if (result.rows != null && result.rows!.isNotEmpty) ...[
            const SizedBox(height: 10),
            AiResultTable(rows: result.rows!),
          ] else if (result.rows != null && result.rows!.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'هیچ ردیفی تحت تأثیر قرار نمی‌گیرد.',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? AppColors.darkTextHint : AppColors.textHint,
              ),
            ),
          ],

          // Action buttons (only if not yet executed)
          if (!alreadyDone) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Execute button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isExecuting ? null : onExecute,
                    icon: isExecuting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(isExecuting ? 'در حال اجرا…' : 'اجرا کن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cancel button
                OutlinedButton.icon(
                  onPressed: isExecuting ? null : onCancel,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('لغو'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Execution error
          if (result.executionError != null) ...[
            const SizedBox(height: 8),
            _ErrorChip(error: result.executionError!, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _ErrorChip extends StatelessWidget {
  final String error;
  final bool isDark;
  const _ErrorChip({required this.error, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.returned.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.returned),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: AppColors.returned),
            ),
          ),
        ],
      ),
    );
  }
}

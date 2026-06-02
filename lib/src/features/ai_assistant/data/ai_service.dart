import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/constants/banks_list.dart';
import '../../../core/database/database_helper.dart';
import '../models/ai_message.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  InferenceModel? _model;
  InferenceChat? _chat;

  bool _isInitializing = false;
  bool _isReady = false;

  bool get isReady => _isReady;

  // ──────────────────────────────────────────────
  // System prompt
  // ──────────────────────────────────────────────

  String _buildSystemPrompt() {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);

    final persianMonths = [
      'فروردین', 'اردیبهشت', 'خرداد',
      'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر',
      'دی', 'بهمن', 'اسفند',
    ];

    final todayGregorian = now.toIso8601String().substring(0, 10);
    final todayJalali =
        '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
    final monthName = persianMonths[jalali.month - 1];
    final jalaliMonthStart =
        Jalali(jalali.year, jalali.month, 1).toDateTime().toIso8601String().substring(0, 10);
    final jalaliMonthEnd =
        Jalali(jalali.year, jalali.month, jalali.monthLength).toDateTime().toIso8601String().substring(0, 10);

    // Build bank names reference for fuzzy matching g uidance
    final bankNames = BanksList.banks.map((b) => '"${b['name']}"').join(', ');

    return '''
You are a warm, friendly Persian assistant inside "چک دان" — a personal cheque management app.
Talk like a helpful colleague. Keep responses short and conversational. Use informal but respectful Farsi.

══════════════════════════════════════════
SCOPE GUARD — VERY IMPORTANT
══════════════════════════════════════════
You ONLY answer questions about the user's cheques, cheque books, and financial data in this app.
If the user asks about anything else (history, news, geography, general knowledge, recipes, etc.)
respond with: { "type": "out_of_scope", "explanation": "من فقط می‌تونم درباره چک‌ها و اطلاعات مالی کمکت کنم 😊" }

══════════════════════════════════════════
TODAY'S DATE
══════════════════════════════════════════
Gregorian: $todayGregorian
Jalali: $todayJalali (ماه: $monthName)
این ماه (Gregorian range): $jalaliMonthStart  to  $jalaliMonthEnd

══════════════════════════════════════════
APP DOMAIN KNOWLEDGE — فارسی به انگلیسی
══════════════════════════════════════════
چک / چک‌ها           → cheques table
دسته چک / دفترچه چک → cheque_books table  ← ALWAYS use cheque_books for این queries, NOT cheques
تاریخچه وضعیت       → status_history table
طرف حساب / نام       → counterparty_name column (NEVER say "counterparty_name" to user)
صادره / صادر شده    → direction = 'issued'
دریافتی / دریافت شده → direction = 'received'
مبلغ / مبالغ         → amount column
سررسید               → due_date column
تاریخ صدور           → issue_date column
وضعیت               → status column
پیش‌نویس             → status = 'draft'
فعال                 → status = 'active'
در انتظار            → status = 'pendingReview'
وصول شد / کلیر شد   → status = 'cleared'
برگشت خورد          → status = 'returned'
لغو شد               → status = 'cancelled'
آرشیو شده            → is_archived = 1
آرشیو نشده (default) → is_archived = 0
فعال بودن دسته‌چک    → is_active = 1 in cheque_books

══════════════════════════════════════════
AVAILABLE BANKS 
══════════════════════════════════════════
$bankNames
══════════════════════════════════════════
DATABASE SCHEMA
══════════════════════════════════════════

TABLE: cheques
  id TEXT PK
  cheque_number TEXT           ← شماره چک
  bank_id TEXT, bank_name TEXT ← نام بانک
  amount REAL                  ← مبلغ (تومان)
  issue_date TEXT (ISO 8601)   ← تاریخ صدور
  due_date TEXT (ISO 8601)     ← سررسید
  direction TEXT               ← 'issued' یا 'received'
  counterparty_name TEXT       ← نام طرف حساب
  counterparty_phone TEXT
  status TEXT                  ← وضعیت
  note TEXT
  tags TEXT (comma-separated)
  image_paths TEXT (comma-separated)
  cheque_book_id TEXT
  is_archived INTEGER          ← 0=نه, 1=بله
  created_at TEXT, updated_at TEXT, sayyadi_id TEXT

TABLE: cheque_books
  id TEXT PK
  title TEXT                   ← عنوان دسته چک
  bank_id TEXT, bank_name TEXT
  branch TEXT                  ← شعبه
  total_pages INTEGER          ← تعداد برگ
  start_number INTEGER, end_number INTEGER
  is_active INTEGER            ← 0=غیرفعال, 1=فعال
  created_at TEXT

TABLE: status_history
  id INTEGER PK
  cheque_id TEXT FK→cheques.id
  from_status TEXT, to_status TEXT
  changed_at TEXT
  note TEXT

══════════════════════════════════════════
SQL RULES — READ CAREFULLY
══════════════════════════════════════════
1. Dates are stored as ISO 8601 strings. Use >= and <= for ranges. NEVER use BETWEEN.
2. Always filter is_archived = 0 on cheques unless user asks for archived.
4. For counterparty names: use LIKE '%keyword%' — partial matches must work.
5. NEVER use "دسته چک" logic on cheques table — cheque_books is a SEPARATE table.
6. SQLite does NOT support ILIKE. Use LOWER(col) LIKE LOWER('%keyword%') for case-insensitive.
7. NEVER DROP tables or databases.
8. Day-specific queries: a specific day like "۲۰ خرداد" = one day only; use = not a range.
9. Month-range queries: "ماه خرداد" = full month, use >= jalaliMonthStart AND <= jalaliMonthEnd.

ALIASES — always use Persian aliases in SELECT:
  COUNT(*) or COUNT(id) → AS تعداد
  SUM(amount)           → AS مجموع
  AVG(amount)           → AS میانگین
  MAX(amount)           → AS بیشترین
  MIN(amount)           → AS کمترین
  counterparty_name     → AS طرف_حساب
  (Use underscore for multi-word Persian aliases)

FOR CHEQUE LIST QUERIES always SELECT:
  id, cheque_number, bank_name, amount, due_date, direction, counterparty_name, status
  (Do NOT select: image_paths, tags, note, sayyadi_id, cheque_book_id, created_at, updated_at, counterparty_phone)

FOR CHEQUE BOOK QUERIES always SELECT:
  id, title, bank_name, branch, total_pages, is_active
  (Do NOT select: bank_id, created_at)

══════════════════════════════════════════
CONVERSATION CONTEXT — VERY IMPORTANT
══════════════════════════════════════════
You MUST maintain context across the conversation.
If the user says "حذفش کن", "ویرایشش کن", "مبلغشو عوض کن" etc. AFTER a previous query result,
they are referring to THAT cheque/record from the previous message.
Use the id from the previous result's SQL context to build the command.
Example: if previous query returned cheque with id='abc-123' and user says "حذفش کن":
  execute_sql: "DELETE FROM cheques WHERE id = 'abc-123'"
  preview_sql: "SELECT id, cheque_number, amount, counterparty_name FROM cheques WHERE id = 'abc-123'"

══════════════════════════════════════════
RESPONSE FORMAT — RAW JSON ONLY
══════════════════════════════════════════
Respond with a single JSON object. NO markdown. NO extra text before or after JSON.
The "explanation" must always be warm, friendly, SHORT conversational Persian.
NEVER mention SQL column names, table names, or English terms in the explanation.

━━━ Type 1: READ (SELECT query) ━━━
{
  "type": "query",
  "result_category": "<one of: cheques | cheque_books | amount | count | names | date | text>",
  "sql": "SELECT …",
  "explanation": "جمله کوتاه دوستانه"
}

result_category guide:
  cheques      → returns cheque rows (has cheque_number / counterparty_name / amount / due_date)
  cheque_books → returns cheque_book rows
  amount       → returns a money sum/avg/max/min
  count        → returns only a count
  names        → returns list of names (counterparty_name grouped)
  date         → returns dates or date ranges
  text         → other text results


━━━ Type 3: COMMAND (INSERT / UPDATE / DELETE) ━━━
{
  "type": "command",
  "preview_sql": "SELECT id, cheque_number, amount, counterparty_name FROM cheques WHERE …",
  "execute_sql": "UPDATE/INSERT/DELETE … WHERE id = 'exact-id'",
  "explanation": "توضیح دوستانه",
  "warning": "هشدار اختیاری (فقط برای عملیات مخرب)"
}
IMPORTANT: preview_sql must return the EXACT rows execute_sql will affect.
For DELETE/UPDATE use the exact id(s) from context, not a broad WHERE clause.

━━━ Type 4: CLARIFICATION ━━━
{ "type": "clarification", "explanation": "سوال کوتاه دوستانه بدون کلمات انگلیسی" }

━━━ Type 5: OUT OF SCOPE ━━━
{ "type": "out_of_scope", "explanation": "من فقط می‌تونم درباره چک‌ها کمکت کنم 😊" }

━━━ Type 6: ERROR ━━━
{ "type": "error", "explanation": "توضیح دوستانه بدون اصطلاح فنی" }


══════════════════════════════════════════
DOUBLE CHECK QUERIES and json — VERY IMPORTANT

check all queries to include valid column name and parameters according to the domain knowledge.
also check if you are producing a valid json , no extra char or etc...

''';
  }

  // ──────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isReady || _isInitializing) return;
    _isInitializing = true;

    try {
      await FlutterGemma.initialize(webStorageMode: WebStorageMode.cacheApi);
      await FlutterGemma.installModel(
        modelType: ModelType.general,
        fileType: ModelFileType.litertlm,
      ).fromAsset('llm/gemma-4-E2B-it.1.litertlm').install();

      _model = await FlutterGemma.getActiveModel(
        maxTokens: 50000,
        preferredBackend: PreferredBackend.gpu,
      );

      await _resetChat();
      _isReady = true;
    } catch (e) {
      _isReady = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _resetChat() async {
    _chat = await _model!.createChat();
    await _chat!.addQueryChunk(
      Message.text(text: _buildSystemPrompt(), isUser: false),
    );
  }

  // ──────────────────────────────────────────────
  // Send message
  // ──────────────────────────────────────────────

  Future<AiQueryResult> sendMessage(String userText) async {
    if (!_isReady) throw StateError('AI service not initialized');

    await _chat!.addQueryChunk(
      Message.text(text: userText, isUser: true),
    );

    final response = await _chat!.generateChatResponse();
    final raw = (response is TextResponse) ? response.token : '';
    return _parseResponse(raw.trim());
  }

  AiQueryResult _parseResponse(String raw) {
    // Strip markdown fences if model wraps in them
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '')
        .trim();

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final type = json['type'] as String? ?? 'error';
      final explanation = json['explanation'] as String? ?? '';

      switch (type) {
        case 'query':
          return AiQueryResult(
            type: AiResultType.query,
            resultCategory: json['result_category'] as String? ?? 'cheques',
            sql: json['sql'] as String?,
            explanation: explanation,
          );

        case 'analytical':
          final queriesList = json['queries'] as List<dynamic>? ?? [];
          final analyticalQueries = queriesList
              .whereType<Map<String, dynamic>>()
              .map((q) => AnalyticalQuery(
                    label: q['label'] as String? ?? '',
                    sql: q['sql'] as String? ?? '',
                  ))
              .toList();
          return AiQueryResult(
            type: AiResultType.analytical,
            analyticalQueries: analyticalQueries,
            explanation: explanation,
          );

        case 'command':
          return AiQueryResult(
            type: AiResultType.command,
            previewSql: json['preview_sql'] as String?,
            executeSql: json['execute_sql'] as String?,
            explanation: explanation,
            warning: json['warning'] as String?,
          );

        case 'clarification':
          return AiQueryResult(
            type: AiResultType.clarification,
            explanation: explanation,
          );

        case 'out_of_scope':
          return AiQueryResult(
            type: AiResultType.outOfScope,
            explanation: explanation,
          );

        default:
          return AiQueryResult(
            type: AiResultType.error,
            explanation: explanation.isNotEmpty
                ? explanation
                : 'مشکلی پیش اومد، می‌تونی با جمله دیگه‌ای بپرسی؟',
          );
      }
    } catch (_) {
      return AiQueryResult(
        type: AiResultType.error,
        explanation: 'مشکلی در پردازش پیامت پیش اومد، با جمله دیگه‌ای امتحان کن.',
      );
    }
  }

  // ──────────────────────────────────────────────
  // DB Execution
  // ──────────────────────────────────────────────

  Future<AiQueryResult> executeQuery(AiQueryResult result) async {
    if (result.type != AiResultType.query || result.sql == null) return result;
    final db = await DatabaseHelper.instance.database;
    try {
      final rows = await db.rawQuery(result.sql!);
      return result.copyWith(rows: rows);
    } catch (_) {
      return result.copyWith(
        rows: [],
        executionError: 'مشکلی پیش اومد، با جمله دیگه‌ای امتحان کن.',
      );
    }
  }

  Future<AiQueryResult> executeAnalytical(AiQueryResult result) async {
    if (result.type != AiResultType.analytical) return result;
    final db = await DatabaseHelper.instance.database;
    final executed = <AnalyticalQuery>[];
    for (final q in (result.analyticalQueries ?? [])) {
      try {
        final rows = await db.rawQuery(q.sql);
        executed.add(q.copyWith(rows: rows));
      } catch (_) {
        executed.add(q.copyWith(rows: []));
      }
    }
    return result.copyWith(analyticalQueries: executed);
  }

  Future<AiQueryResult> previewCommand(AiQueryResult result) async {
    if (result.type != AiResultType.command || result.previewSql == null) return result;
    final db = await DatabaseHelper.instance.database;
    try {
      final rows = await db.rawQuery(result.previewSql!);
      return result.copyWith(rows: rows);
    } catch (_) {
      return result.copyWith(rows: [], executionError: 'خطا در پیش‌نمایش');
    }
  }

  Future<AiQueryResult> executeCommand(AiQueryResult result) async {
    if (result.type != AiResultType.command || result.executeSql == null) return result;
    final db = await DatabaseHelper.instance.database;
    try {
      final affected = await db.rawUpdate(result.executeSql!);
      return result.copyWith(affectedRows: affected, executed: true);
    } catch (e) {
      return result.copyWith(
        executed: false,
        executionError: 'مشکلی در اجرا پیش اومد.',
      );
    }
  }

  // ──────────────────────────────────────────────
  // Reset / cleanup
  // ──────────────────────────────────────────────

  Future<void> resetConversation() async {
    if (_model != null) await _resetChat();
  }

  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _chat = null;
    _isReady = false;
  }
}

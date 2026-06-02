import 'package:equatable/equatable.dart';

enum AiMessageRole { user, assistant }

enum AiResultType {
  query,
  analytical,
  command,
  clarification,
  outOfScope,
  error,
}

/// A single sub-query in an analytical (multi-query) response
class AnalyticalQuery extends Equatable {
  final String label;
  final String sql;
  final List<Map<String, dynamic>>? rows;

  const AnalyticalQuery({
    required this.label,
    required this.sql,
    this.rows,
  });

  AnalyticalQuery copyWith({List<Map<String, dynamic>>? rows}) =>
      AnalyticalQuery(label: label, sql: sql, rows: rows ?? this.rows);

  @override
  List<Object?> get props => [label, sql, rows];
}

/// Represents a single message in the AI chat
class AiMessage extends Equatable {
  final String id;
  final AiMessageRole role;
  final String text;
  final DateTime timestamp;
  final AiQueryResult? result;
  final bool isLoading;

  const AiMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.result,
    this.isLoading = false,
  });

  AiMessage copyWith({
    String? text,
    AiQueryResult? result,
    bool? isLoading,
  }) =>
      AiMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        timestamp: timestamp,
        result: result ?? this.result,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [id, role, text, timestamp, result, isLoading];
}

/// Parsed result from the LLM
class AiQueryResult extends Equatable {
  final AiResultType type;
  final String? resultCategory; // 'cheques' | 'cheque_books' | 'amount' | 'count' | 'names' | 'date' | 'text'
  final String? sql;
  final String? previewSql;
  final String? executeSql;
  final String explanation;
  final String? warning;
  final List<AnalyticalQuery>? analyticalQueries;

  // Populated after DB execution
  final List<Map<String, dynamic>>? rows;
  final int? affectedRows;
  final bool? executed;
  final String? executionError;

  const AiQueryResult({
    required this.type,
    this.resultCategory,
    this.sql,
    this.previewSql,
    this.executeSql,
    required this.explanation,
    this.warning,
    this.analyticalQueries,
    this.rows,
    this.affectedRows,
    this.executed,
    this.executionError,
  });

  AiQueryResult copyWith({
    String? resultCategory,
    List<Map<String, dynamic>>? rows,
    int? affectedRows,
    bool? executed,
    String? executionError,
    List<AnalyticalQuery>? analyticalQueries,
  }) =>
      AiQueryResult(
        type: type,
        resultCategory: resultCategory ?? this.resultCategory,
        sql: sql,
        previewSql: previewSql,
        executeSql: executeSql,
        explanation: explanation,
        warning: warning,
        analyticalQueries: analyticalQueries ?? this.analyticalQueries,
        rows: rows ?? this.rows,
        affectedRows: affectedRows ?? this.affectedRows,
        executed: executed ?? this.executed,
        executionError: executionError ?? this.executionError,
      );

  @override
  List<Object?> get props => [
        type, resultCategory, sql, previewSql, executeSql,
        explanation, warning, analyticalQueries,
        rows, affectedRows, executed, executionError,
      ];
}

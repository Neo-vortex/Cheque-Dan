import 'package:equatable/equatable.dart';
import '../services/time_origin_service.dart';

enum ChequeDirection { issued, received }

enum ChequeStatus {
  draft,
  active,
  pendingReview,
  cleared,
  returned,
  cancelled,
}

extension ChequeStatusX on ChequeStatus {
  bool get isActive =>
      this != ChequeStatus.cleared &&
          this != ChequeStatus.cancelled &&
          this != ChequeStatus.returned;
}

enum DueDateState { upcoming, dueToday, overdue, future, cleared }

class StatusChange {
  final ChequeStatus fromStatus;
  final ChequeStatus toStatus;
  final DateTime changedAt;
  final String? note;

  const StatusChange({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'from_status': fromStatus.name,
    'to_status': toStatus.name,
    'changed_at': changedAt.toIso8601String(),
    'note': note,
  };

  factory StatusChange.fromMap(Map<String, dynamic> map) => StatusChange(
    fromStatus: ChequeStatus.values.byName(map['from_status']),
    toStatus: ChequeStatus.values.byName(map['to_status']),
    changedAt: DateTime.parse(map['changed_at']),
    note: map['note'],
  );
}

class Cheque extends Equatable {
  final String id;
  final String sayyadiId;
  final String chequeNumber;
  final String bankId;
  final String bankName;
  final double amount;
  final DateTime issueDate;
  final DateTime dueDate;
  final ChequeDirection direction;
  final String counterpartyName;
  final String? counterpartyPhone;
  final ChequeStatus status;
  final String? note;
  final List<String> tags;
  final List<StatusChange> statusHistory;
  final List<String> imagePaths;
  final String? chequeBookId;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cheque({
    required this.id,
    required this.sayyadiId,
    required this.chequeNumber,
    required this.bankId,
    required this.bankName,
    required this.amount,
    required this.issueDate,
    required this.dueDate,
    required this.direction,
    required this.counterpartyName,
    this.counterpartyPhone,
    required this.status,
    this.note,
    this.tags = const [],
    this.statusHistory = const [],
    this.imagePaths = const [],
    this.chequeBookId,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DueDateState get dueDateState {
    if (status == ChequeStatus.cleared ||
        status == ChequeStatus.cancelled ||
        status == ChequeStatus.returned) {
      return DueDateState.cleared;
    }
    final today = TimeOriginService.instance.today;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) return DueDateState.overdue;
    if (due.isAtSameMomentAs(today)) return DueDateState.dueToday;
    final diff = due.difference(today).inDays;
    if (diff <= 7) return DueDateState.upcoming;
    return DueDateState.future;
  }

  bool get isActive =>
      status != ChequeStatus.cleared &&
          status != ChequeStatus.cancelled &&
          status != ChequeStatus.returned;

  int get daysUntilDue => TimeOriginService.instance.daysUntil(dueDate);

  Cheque copyWith({
    String? id,
    String? sayyadiId,
    String? chequeNumber,
    String? bankId,
    String? bankName,
    double? amount,
    DateTime? issueDate,
    DateTime? dueDate,
    ChequeDirection? direction,
    String? counterpartyName,
    String? counterpartyPhone,
    ChequeStatus? status,
    String? note,
    List<String>? tags,
    List<StatusChange>? statusHistory,
    List<String>? imagePaths,
    String? chequeBookId,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cheque(
      id: id ?? this.id,
      sayyadiId: sayyadiId ?? this.sayyadiId,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      direction: direction ?? this.direction,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      counterpartyPhone: counterpartyPhone ?? this.counterpartyPhone,
      status: status ?? this.status,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      statusHistory: statusHistory ?? this.statusHistory,
      imagePaths: imagePaths ?? this.imagePaths,
      chequeBookId: chequeBookId ?? this.chequeBookId,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sayyadi_id': sayyadiId,
      'cheque_number': chequeNumber,
      'bank_id': bankId,
      'bank_name': bankName,
      'amount': amount,
      'issue_date': issueDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'direction': direction.name,
      'counterparty_name': counterpartyName,
      'counterparty_phone': counterpartyPhone,
      'status': status.name,
      'note': note,
      'tags': tags.join(','),
      'image_paths': imagePaths.join('|'),
      'cheque_book_id': chequeBookId,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Cheque.fromMap(Map<String, dynamic> map, List<StatusChange> history) {
    return Cheque(
      id: map['id'],
      sayyadiId: map['sayyadi_id'],
      chequeNumber: map['cheque_number'],
      bankId: map['bank_id'],
      bankName: map['bank_name'],
      amount: (map['amount'] as num).toDouble(),
      issueDate: DateTime.parse(map['issue_date']),
      dueDate: DateTime.parse(map['due_date']),
      direction: ChequeDirection.values.byName(map['direction']),
      counterpartyName: map['counterparty_name'],
      counterpartyPhone: map['counterparty_phone'],
      status: ChequeStatus.values.byName(map['status']),
      note: map['note'],
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : [],
      imagePaths: map['image_paths'] != null &&
          (map['image_paths'] as String).isNotEmpty
          ? (map['image_paths'] as String).split('|')
          : [],
      chequeBookId: map['cheque_book_id'],
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      statusHistory: history,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  @override
  List<Object?> get props => [
    id, sayyadiId, chequeNumber, bankId, amount,
    issueDate, dueDate, direction, counterpartyName, counterpartyPhone,
    status, note, tags, imagePaths, updatedAt,
  ];
}

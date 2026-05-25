import 'package:equatable/equatable.dart';

class ChequeBook extends Equatable {
  final String id;
  final String title;        // عنوان
  final String bankId;
  final String bankName;     // نام بانک
  final String branch;       // شعبه
  final int totalPages;      // تعداد برگ
  final int startNumber;     // شروع شماره
  final int endNumber;       // پایان شماره
  final bool isActive;       // فعال/غیرفعال
  final DateTime createdAt;

  const ChequeBook({
    required this.id,
    required this.title,
    required this.bankId,
    required this.bankName,
    required this.branch,
    required this.totalPages,
    required this.startNumber,
    required this.endNumber,
    required this.isActive,
    required this.createdAt,
  });

  int get usedPages => endNumber - startNumber + 1 - remainingPages;

  int get remainingPages {
    // This will be computed from DB, default to full
    return totalPages;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'bank_id': bankId,
        'bank_name': bankName,
        'branch': branch,
        'total_pages': totalPages,
        'start_number': startNumber,
        'end_number': endNumber,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChequeBook.fromMap(Map<String, dynamic> map) => ChequeBook(
        id: map['id'],
        title: map['title'],
        bankId: map['bank_id'],
        bankName: map['bank_name'],
        branch: map['branch'],
        totalPages: map['total_pages'] as int,
        startNumber: map['start_number'] as int,
        endNumber: map['end_number'] as int,
        isActive: (map['is_active'] as int) == 1,
        createdAt: DateTime.parse(map['created_at']),
      );

  ChequeBook copyWith({
    String? id,
    String? title,
    String? bankId,
    String? bankName,
    String? branch,
    int? totalPages,
    int? startNumber,
    int? endNumber,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      ChequeBook(
        id: id ?? this.id,
        title: title ?? this.title,
        bankId: bankId ?? this.bankId,
        bankName: bankName ?? this.bankName,
        branch: branch ?? this.branch,
        totalPages: totalPages ?? this.totalPages,
        startNumber: startNumber ?? this.startNumber,
        endNumber: endNumber ?? this.endNumber,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props =>
      [id, title, bankId, bankName, branch, totalPages, startNumber, endNumber, isActive];
}

/// Represents a single leaf (برگ) in a cheque book and which cheque used it
class ChequeBookPage extends Equatable {
  final int pageNumber;
  final String? chequeId;           // null = unused
  final String? counterpartyName;   // for display
  final double? amount;

  const ChequeBookPage({
    required this.pageNumber,
    this.chequeId,
    this.counterpartyName,
    this.amount,
  });

  bool get isUsed => chequeId != null;

  @override
  List<Object?> get props => [pageNumber, chequeId];
}

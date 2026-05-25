import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/time_origin_service.dart';
import '../../../core/models/cheque_model.dart';


class ChequeRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<Cheque>> getAllCheques() async {
    final rows = await _db.getAllCheques();
    return Future.wait(rows.map(_rowToCheque));
  }

  Future<Cheque?> getChequeById(String id) async {
    final row = await _db.getChequeById(id);
    if (row == null) return null;
    return _rowToCheque(row);
  }

  Future<Cheque> createCheque({
    required String sayyadiId,
    required String chequeNumber,
    required String bankId,
    required String bankName,
    required double amount,
    required DateTime issueDate,
    required DateTime dueDate,
    required ChequeDirection direction,
    required String counterpartyName,
    String? counterpartyPhone,
    ChequeStatus status = ChequeStatus.active,
    String? note,
    List<String> tags = const [],
    List<String> imagePaths = const [],
    String? chequeBookId,
  }) async {
    final now = DateTime.now();
    final cheque = Cheque(
      id: _uuid.v4(),
      sayyadiId: sayyadiId,
      chequeNumber: chequeNumber,
      bankId: bankId,
      bankName: bankName,
      amount: amount,
      issueDate: issueDate,
      dueDate: dueDate,
      direction: direction,
      counterpartyName: counterpartyName,
      counterpartyPhone: counterpartyPhone,
      status: status,
      note: note,
      tags: tags,
      imagePaths: imagePaths,
      chequeBookId: chequeBookId,
      statusHistory: [],
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertCheque(cheque.toMap());
    return cheque;
  }

  Future<Cheque> updateCheque(Cheque cheque) async {
    final updated = cheque.copyWith(updatedAt: DateTime.now());
    await _db.updateCheque(updated.toMap());
    return updated;
  }

  Future<Cheque> updateStatus(
      Cheque cheque,
      ChequeStatus newStatus, {
        String? note,
      }) async {
    final change = StatusChange(
      fromStatus: cheque.status,
      toStatus: newStatus,
      changedAt: DateTime.now(),
      note: note,
    );
    await _db.insertStatusChange(cheque.id, change.toMap());

    final updated = cheque.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
      statusHistory: [...cheque.statusHistory, change],
    );
    await _db.updateCheque(updated.toMap());
    return updated;
  }

  Future<void> deleteCheque(String id) async {
    await _db.deleteCheque(id);
  }

  Future<bool> sayyadiIdExists(String sayyadiId, {String? excludeId}) async {
    return _db.sayyadiIdExists(sayyadiId, excludeId: excludeId);
  }

  Future<List<Cheque>> searchCheques(String query) async {
    if (query.trim().isEmpty) return getAllCheques();
    final rows = await _db.searchCheques(query.trim());
    return Future.wait(rows.map(_rowToCheque));
  }

  Future<bool> hasChequesNeedingAttention({int reminderDays = 3}) async {
    final rows = await _db.getChequesNeedingAttention(reminderDays);
    return rows.isNotEmpty;
  }

  Future<List<Cheque>> getChequesNeedingAttention({int reminderDays = 3}) async {
    final rows = await _db.getChequesNeedingAttention(reminderDays);
    return Future.wait(rows.map(_rowToCheque));
  }

  Future<DashboardSummary> getDashboardSummary() async {
    final cheques = await getAllCheques();

    final active = cheques.where((c) => c.isActive).toList();
    final issued = active.where((c) => c.direction == ChequeDirection.issued).toList();
    final received = active.where((c) => c.direction == ChequeDirection.received).toList();

    final overdueList = active
        .where((c) => c.dueDateState == DueDateState.overdue)
        .toList();
    final dueTodayList = active
        .where((c) => c.dueDateState == DueDateState.dueToday)
        .toList();
    final upcomingList = active
        .where((c) =>
    c.dueDateState == DueDateState.upcoming ||
        c.dueDateState == DueDateState.dueToday)
        .toList();

    final totalIssuedAmount = issued.fold(0.0, (s, c) => s + c.amount);
    final totalReceivedAmount = received.fold(0.0, (s, c) => s + c.amount);
    final overdueAmount = overdueList.fold(0.0, (s, c) => s + c.amount);

    RiskLevel risk;
    if (overdueList.isNotEmpty || overdueAmount > 0) {
      risk = RiskLevel.critical;
    } else if (dueTodayList.isNotEmpty) {
      risk = RiskLevel.warning;
    } else {
      risk = RiskLevel.safe;
    }

    return DashboardSummary(
      totalIssuedAmount: totalIssuedAmount,
      totalReceivedAmount: totalReceivedAmount,
      overdueCount: overdueList.length,
      overdueAmount: overdueAmount,
      upcomingCheques: upcomingList,
      riskLevel: risk,
      allActiveCheques: active,
    );
  }

  Future<List<CashflowPoint>> getCashflowForecast({int days = 30}) async {
    final cheques = await getAllCheques();
    final active = cheques.where((c) => c.isActive).toList();

    final today = TimeOriginService.instance.today;
    final List<CashflowPoint> points = [];

    double runningBalance = 0;

    for (int i = 0; i <= days; i++) {
      final day = today.add(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));

      final dayReceived = active
          .where((c) =>
      c.direction == ChequeDirection.received &&
          !c.dueDate.isBefore(day) &&
          c.dueDate.isBefore(dayEnd))
          .fold(0.0, (s, c) => s + c.amount);

      final dayIssued = active
          .where((c) =>
      c.direction == ChequeDirection.issued &&
          !c.dueDate.isBefore(day) &&
          c.dueDate.isBefore(dayEnd))
          .fold(0.0, (s, c) => s + c.amount);

      runningBalance += dayReceived - dayIssued;
      points.add(CashflowPoint(
        date: day,
        balance: runningBalance,
        incoming: dayReceived,
        outgoing: dayIssued,
      ));
    }

    return points;
  }

  Future<Cheque> _rowToCheque(Map<String, dynamic> row) async {
    final history = await _db.getStatusHistory(row['id']);
    return Cheque.fromMap(
      row,
      history.map(StatusChange.fromMap).toList(),
    );
  }
}

enum RiskLevel { safe, warning, critical }

class DashboardSummary {
  final double totalIssuedAmount;
  final double totalReceivedAmount;
  final int overdueCount;
  final double overdueAmount;
  final List<Cheque> upcomingCheques;
  final RiskLevel riskLevel;
  final List<Cheque> allActiveCheques;

  const DashboardSummary({
    required this.totalIssuedAmount,
    required this.totalReceivedAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.upcomingCheques,
    required this.riskLevel,
    required this.allActiveCheques,
  });

  double get netPosition => totalReceivedAmount - totalIssuedAmount;
}

class CashflowPoint {
  final DateTime date;
  final double balance;
  final double incoming;
  final double outgoing;

  const CashflowPoint({
    required this.date,
    required this.balance,
    required this.incoming,
    required this.outgoing,
  });
}

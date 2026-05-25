part of 'cheque_bloc.dart';

abstract class ChequeEvent extends Equatable {
  const ChequeEvent();

  @override
  List<Object?> get props => [];
}

class LoadChequesEvent extends ChequeEvent {
  const LoadChequesEvent();
}

class CreateChequeEvent extends ChequeEvent {
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
  final List<String> imagePaths;
  final String? chequeBookId;

  const CreateChequeEvent({
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
    this.status = ChequeStatus.active,
    this.note,
    this.tags = const [],
    this.imagePaths = const [],
    this.chequeBookId,
  });

  @override
  List<Object?> get props => [sayyadiId, chequeNumber, amount, dueDate];
}

class UpdateChequeEvent extends ChequeEvent {
  final Cheque cheque;

  const UpdateChequeEvent(this.cheque);

  @override
  List<Object?> get props => [cheque];
}

class UpdateChequeStatusEvent extends ChequeEvent {
  final Cheque cheque;
  final ChequeStatus newStatus;
  final String? note;

  const UpdateChequeStatusEvent({
    required this.cheque,
    required this.newStatus,
    this.note,
  });

  @override
  List<Object?> get props => [cheque.id, newStatus];
}

class DeleteChequeEvent extends ChequeEvent {
  final String chequeId;

  const DeleteChequeEvent(this.chequeId);

  @override
  List<Object?> get props => [chequeId];
}

class SearchChequesEvent extends ChequeEvent {
  final String query;

  const SearchChequesEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearSearchEvent extends ChequeEvent {
  const ClearSearchEvent();
}

class BulkUpdateStatusEvent extends ChequeEvent {
  final List<Cheque> cheques;
  final ChequeStatus newStatus;

  const BulkUpdateStatusEvent({
    required this.cheques,
    required this.newStatus,
  });

  @override
  List<Object?> get props => [cheques.length, newStatus];
}

class ArchiveChequeEvent extends ChequeEvent {
  final String chequeId;
  const ArchiveChequeEvent(this.chequeId);
  @override
  List<Object?> get props => [chequeId];
}

class UnarchiveChequeEvent extends ChequeEvent {
  final String chequeId;
  const UnarchiveChequeEvent(this.chequeId);
  @override
  List<Object?> get props => [chequeId];
}

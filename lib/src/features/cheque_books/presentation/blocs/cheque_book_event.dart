part of 'cheque_book_bloc.dart';

abstract class ChequeBookEvent extends Equatable {
  const ChequeBookEvent();
  @override
  List<Object?> get props => [];
}

class LoadChequeBooksEvent extends ChequeBookEvent {
  const LoadChequeBooksEvent();
}

class CreateChequeBookEvent extends ChequeBookEvent {
  final String title;
  final String bankId;
  final String bankName;
  final String branch;
  final int totalPages;
  final int startNumber;
  final int endNumber;

  const CreateChequeBookEvent({
    required this.title,
    required this.bankId,
    required this.bankName,
    required this.branch,
    required this.totalPages,
    required this.startNumber,
    required this.endNumber,
  });

  @override
  List<Object?> get props => [title, bankId, startNumber, endNumber];
}

class UpdateChequeBookEvent extends ChequeBookEvent {
  final ChequeBook book;
  const UpdateChequeBookEvent(this.book);
  @override
  List<Object?> get props => [book];
}

class DeleteChequeBookEvent extends ChequeBookEvent {
  final String bookId;
  const DeleteChequeBookEvent(this.bookId);
  @override
  List<Object?> get props => [bookId];
}

class ToggleChequeBookActiveEvent extends ChequeBookEvent {
  final ChequeBook book;
  const ToggleChequeBookActiveEvent(this.book);
  @override
  List<Object?> get props => [book.id];
}

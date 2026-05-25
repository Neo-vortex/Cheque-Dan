part of 'cheque_book_bloc.dart';

abstract class ChequeBookState extends Equatable {
  const ChequeBookState();
  @override
  List<Object?> get props => [];
}

class ChequeBookInitial extends ChequeBookState {
  const ChequeBookInitial();
}

class ChequeBooksLoading extends ChequeBookState {
  const ChequeBooksLoading();
}

class ChequeBooksLoaded extends ChequeBookState {
  final List<EnrichedChequeBook> books;
  const ChequeBooksLoaded({required this.books});
  @override
  List<Object?> get props => [books.length];
}

class ChequeBookError extends ChequeBookState {
  final String message;
  const ChequeBookError(this.message);
  @override
  List<Object?> get props => [message];
}

part of 'cheque_bloc.dart';

abstract class ChequeState extends Equatable {
  const ChequeState();

  @override
  List<Object?> get props => [];
}

class ChequeInitial extends ChequeState {
  const ChequeInitial();
}

class ChequesLoading extends ChequeState {
  const ChequesLoading();
}

class ChequesLoaded extends ChequeState {
  final List<Cheque> cheques;
  final List<Cheque>? searchResults;
  final String? searchQuery;

  const ChequesLoaded({
    required this.cheques,
    this.searchResults,
    this.searchQuery,
  });

  List<Cheque> get displayCheques => searchResults ?? cheques;

  bool get isSearching =>
      searchQuery != null && searchQuery!.isNotEmpty;

  @override
  List<Object?> get props => [cheques, searchResults, searchQuery];
}

class ChequeOperationInProgress extends ChequeState {
  const ChequeOperationInProgress();
}

class ChequeOperationSuccess extends ChequeState {
  final String message;
  final List<Cheque> cheques;

  const ChequeOperationSuccess({
    required this.message,
    required this.cheques,
  });

  @override
  List<Object?> get props => [message, cheques];
}

class ChequeOperationFailure extends ChequeState {
  final String error;
  final List<Cheque> cheques;

  const ChequeOperationFailure({
    required this.error,
    required this.cheques,
  });

  @override
  List<Object?> get props => [error, cheques];
}

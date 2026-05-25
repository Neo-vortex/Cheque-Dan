import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/cheque_book_model.dart';
import '../../data/cheque_book_repository.dart';


part 'cheque_book_event.dart';
part 'cheque_book_state.dart';

class ChequeBookBloc extends Bloc<ChequeBookEvent, ChequeBookState> {
  final ChequeBookRepository _repo;
  List<ChequeBook> _all = [];

  ChequeBookBloc(this._repo) : super(const ChequeBookInitial()) {
    on<LoadChequeBooksEvent>(_onLoad);
    on<CreateChequeBookEvent>(_onCreate);
    on<UpdateChequeBookEvent>(_onUpdate);
    on<DeleteChequeBookEvent>(_onDelete);
    on<ToggleChequeBookActiveEvent>(_onToggleActive);
  }

  Future<void> _onLoad(LoadChequeBooksEvent e, Emitter<ChequeBookState> emit) async {
    emit(const ChequeBooksLoading());
    try {
      _all = await _repo.getAllChequeBooks();
      // Enrich with remaining pages
      final enriched = await Future.wait(_all.map(_enrich));
      emit(ChequeBooksLoaded(books: enriched));
    } catch (err) {
      emit(ChequeBookError('خطا در بارگذاری دسته چک‌ها: $err'));
    }
  }

  Future<void> _onCreate(CreateChequeBookEvent e, Emitter<ChequeBookState> emit) async {
    try {
      await _repo.createChequeBook(
        title: e.title,
        bankId: e.bankId,
        bankName: e.bankName,
        branch: e.branch,
        totalPages: e.totalPages,
        startNumber: e.startNumber,
        endNumber: e.endNumber,
      );
      add(const LoadChequeBooksEvent());
    } catch (err) {
      emit(ChequeBookError('خطا در ثبت دسته چک: $err'));
    }
  }

  Future<void> _onUpdate(UpdateChequeBookEvent e, Emitter<ChequeBookState> emit) async {
    try {
      await _repo.updateChequeBook(e.book);
      add(const LoadChequeBooksEvent());
    } catch (err) {
      emit(ChequeBookError('خطا در ویرایش دسته چک: $err'));
    }
  }

  Future<void> _onDelete(DeleteChequeBookEvent e, Emitter<ChequeBookState> emit) async {
    try {
      await _repo.deleteChequeBook(e.bookId);
      add(const LoadChequeBooksEvent());
    } catch (err) {
      emit(ChequeBookError('خطا در حذف دسته چک: $err'));
    }
  }

  Future<void> _onToggleActive(ToggleChequeBookActiveEvent e, Emitter<ChequeBookState> emit) async {
    try {
      final updated = e.book.copyWith(isActive: !e.book.isActive);
      await _repo.updateChequeBook(updated);
      add(const LoadChequeBooksEvent());
    } catch (err) {
      emit(ChequeBookError('خطا: $err'));
    }
  }

  Future<EnrichedChequeBook> _enrich(ChequeBook book) async {
    final remaining = await _repo.getRemainingPages(book);
    return EnrichedChequeBook(book: book, remainingPages: remaining);
  }
}

class EnrichedChequeBook {
  final ChequeBook book;
  final int remainingPages;
  EnrichedChequeBook({required this.book, required this.remainingPages});
  int get usedPages => book.totalPages - remainingPages;
}

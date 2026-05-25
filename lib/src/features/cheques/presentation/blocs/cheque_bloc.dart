import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/cheque_model.dart';
import '../../data/cheque_repository.dart';

part 'cheque_event.dart';
part 'cheque_state.dart';

class ChequeBloc extends Bloc<ChequeEvent, ChequeState> {
  final ChequeRepository _repository;
  List<Cheque> _allCheques = [];

  ChequeBloc(this._repository) : super(const ChequeInitial()) {
    on<LoadChequesEvent>(_onLoadCheques);
    on<CreateChequeEvent>(_onCreateCheque);
    on<UpdateChequeEvent>(_onUpdateCheque);
    on<UpdateChequeStatusEvent>(_onUpdateStatus);
    on<DeleteChequeEvent>(_onDeleteCheque);
    on<SearchChequesEvent>(_onSearch);
    on<ClearSearchEvent>(_onClearSearch);
    on<BulkUpdateStatusEvent>(_onBulkUpdateStatus);
    on<ArchiveChequeEvent>(_onArchive);
    on<UnarchiveChequeEvent>(_onUnarchive);
  }

  Future<void> _onLoadCheques(
      LoadChequesEvent event, Emitter<ChequeState> emit) async {
    emit(const ChequesLoading());
    try {
      _allCheques = await _repository.getAllCheques();
      emit(ChequesLoaded(cheques: _allCheques));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در بارگذاری چک‌ها: $e', cheques: []));
    }
  }

  Future<void> _onCreateCheque(
      CreateChequeEvent event, Emitter<ChequeState> emit) async {
    try {
      final exists = await _repository.sayyadiIdExists(event.sayyadiId);
      if (exists) {
        emit(ChequeOperationFailure(
          error: 'شناسه صیادی تکراری است',
          cheques: _allCheques,
        ));
        return;
      }

      final cheque = await _repository.createCheque(
        sayyadiId: event.sayyadiId,
        chequeNumber: event.chequeNumber,
        bankId: event.bankId,
        bankName: event.bankName,
        amount: event.amount,
        issueDate: event.issueDate,
        dueDate: event.dueDate,
        direction: event.direction,
        counterpartyName: event.counterpartyName,
        counterpartyPhone: event.counterpartyPhone,
        status: event.status,
        note: event.note,
        tags: event.tags,
        imagePaths: event.imagePaths,
        chequeBookId: event.chequeBookId,
      );

      _allCheques = [..._allCheques, cheque];
      _allCheques.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      emit(ChequeOperationSuccess(
        message: 'چک با موفقیت ثبت شد',
        cheques: _allCheques,
      ));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در ثبت چک: $e', cheques: _allCheques));
    }
  }

  Future<void> _onUpdateCheque(
      UpdateChequeEvent event, Emitter<ChequeState> emit) async {
    try {
      final exists = await _repository.sayyadiIdExists(
        event.cheque.sayyadiId,
        excludeId: event.cheque.id,
      );
      if (exists) {
        emit(ChequeOperationFailure(
          error: 'شناسه صیادی تکراری است',
          cheques: _allCheques,
        ));
        return;
      }

      final updated = await _repository.updateCheque(event.cheque);
      _allCheques = _allCheques
          .map((c) => c.id == updated.id ? updated : c)
          .toList();

      emit(ChequeOperationSuccess(
        message: 'چک با موفقیت ویرایش شد',
        cheques: _allCheques,
      ));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در ویرایش چک: $e', cheques: _allCheques));
    }
  }

  Future<void> _onUpdateStatus(
      UpdateChequeStatusEvent event, Emitter<ChequeState> emit) async {
    try {
      final updated = await _repository.updateStatus(
        event.cheque,
        event.newStatus,
        note: event.note,
      );
      _allCheques = _allCheques
          .map((c) => c.id == updated.id ? updated : c)
          .toList();

      emit(ChequesLoaded(cheques: _allCheques));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در تغییر وضعیت: $e', cheques: _allCheques));
    }
  }

  Future<void> _onDeleteCheque(
      DeleteChequeEvent event, Emitter<ChequeState> emit) async {
    try {
      await _repository.deleteCheque(event.chequeId);
      _allCheques =
          _allCheques.where((c) => c.id != event.chequeId).toList();

      emit(ChequeOperationSuccess(
        message: 'چک حذف شد',
        cheques: _allCheques,
      ));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در حذف چک: $e', cheques: _allCheques));
    }
  }

  Future<void> _onSearch(
      SearchChequesEvent event, Emitter<ChequeState> emit) async {
    try {
      if (event.query.trim().isEmpty) {
        emit(ChequesLoaded(cheques: _allCheques));
        return;
      }
      final results = await _repository.searchCheques(event.query);
      emit(ChequesLoaded(
        cheques: _allCheques,
        searchResults: results,
        searchQuery: event.query,
      ));
    } catch (e) {
      emit(ChequesLoaded(cheques: _allCheques));
    }
  }

  Future<void> _onClearSearch(
      ClearSearchEvent event, Emitter<ChequeState> emit) async {
    emit(ChequesLoaded(cheques: _allCheques));
  }

  Future<void> _onBulkUpdateStatus(
      BulkUpdateStatusEvent event, Emitter<ChequeState> emit) async {
    try {
      for (final cheque in event.cheques) {
        final updated = await _repository.updateStatus(cheque, event.newStatus);
        _allCheques = _allCheques
            .map((c) => c.id == updated.id ? updated : c)
            .toList();
      }

      emit(ChequesLoaded(cheques: _allCheques));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در به‌روزرسانی دسته‌ای: $e',
          cheques: _allCheques));
    }
  }

  Future<void> _onArchive(
      ArchiveChequeEvent event, Emitter<ChequeState> emit) async {
    try {
      final cheque = _allCheques.firstWhere((c) => c.id == event.chequeId);
      final updated = await _repository.updateCheque(
          cheque.copyWith(isArchived: true));
      _allCheques =
          _allCheques.map((c) => c.id == updated.id ? updated : c).toList();
      emit(ChequeOperationSuccess(
          message: 'چک به آرشیو منتقل شد', cheques: _allCheques));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا در آرشیو چک: $e', cheques: _allCheques));
    }
  }

  Future<void> _onUnarchive(
      UnarchiveChequeEvent event, Emitter<ChequeState> emit) async {
    try {
      final cheque = _allCheques.firstWhere((c) => c.id == event.chequeId);
      final updated = await _repository.updateCheque(
          cheque.copyWith(isArchived: false));
      _allCheques =
          _allCheques.map((c) => c.id == updated.id ? updated : c).toList();
      emit(ChequeOperationSuccess(
          message: 'چک از آرشیو خارج شد', cheques: _allCheques));
    } catch (e) {
      emit(ChequeOperationFailure(
          error: 'خطا: $e', cheques: _allCheques));
    }
  }
}

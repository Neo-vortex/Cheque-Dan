import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/cheque_book_model.dart';

class ChequeBookRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<ChequeBook>> getAllChequeBooks() async {
    final rows = await _db.getAllChequeBooks();
    return rows.map(ChequeBook.fromMap).toList();
  }

  Future<ChequeBook?> getChequeBookById(String id) async {
    final row = await _db.getChequeBookById(id);
    return row == null ? null : ChequeBook.fromMap(row);
  }

  Future<ChequeBook> createChequeBook({
    required String title,
    required String bankId,
    required String bankName,
    required String branch,
    required int totalPages,
    required int startNumber,
    required int endNumber,
  }) async {
    final book = ChequeBook(
      id: _uuid.v4(),
      title: title,
      bankId: bankId,
      bankName: bankName,
      branch: branch,
      totalPages: totalPages,
      startNumber: startNumber,
      endNumber: endNumber,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _db.insertChequeBook(book.toMap());
    return book;
  }

  Future<ChequeBook> updateChequeBook(ChequeBook book) async {
    await _db.updateChequeBook(book.toMap());
    return book;
  }

  Future<void> deleteChequeBook(String id) async {
    await _db.deleteChequeBook(id);
  }

  Future<List<ChequeBookPage>> getPagesForBook(ChequeBook book) async {
    final usedRows = await _db.getChequesForBook(book.id);
    final usedMap = <int, Map<String, dynamic>>{};
    for (final row in usedRows) {
      final num = int.tryParse(row['cheque_number'] as String? ?? '');
      if (num != null) usedMap[num] = row;
    }

    final pages = <ChequeBookPage>[];
    for (int n = book.startNumber; n <= book.endNumber; n++) {
      final row = usedMap[n];
      pages.add(ChequeBookPage(
        pageNumber: n,
        chequeId: row?['id'] as String?,
        counterpartyName: row?['counterparty_name'] as String?,
        amount: row != null ? (row['amount'] as num?)?.toDouble() : null,
      ));
    }
    return pages;
  }

  Future<int> getRemainingPages(ChequeBook book) async {
    final rows = await _db.getChequesForBook(book.id);
    return book.totalPages - rows.length;
  }

  Future<int?> getNextAvailablePage(ChequeBook book) async {
    final rows = await _db.getChequesForBook(book.id);
    final usedNumbers = rows
        .map((r) => int.tryParse(r['cheque_number'] as String? ?? ''))
        .whereType<int>()
        .toSet();
    for (int n = book.startNumber; n <= book.endNumber; n++) {
      if (!usedNumbers.contains(n)) return n;
    }
    return null;
  }
}

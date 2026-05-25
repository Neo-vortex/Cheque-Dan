import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cheque_app.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cheques (
        id TEXT PRIMARY KEY,
        sayyadi_id TEXT NOT NULL UNIQUE,
        cheque_number TEXT NOT NULL,
        bank_id TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        amount REAL NOT NULL,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        direction TEXT NOT NULL,
        counterparty_name TEXT NOT NULL,
        counterparty_phone TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        note TEXT,
        tags TEXT DEFAULT '',
        image_paths TEXT DEFAULT '',
        cheque_book_id TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cheque_books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        bank_id TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        branch TEXT NOT NULL,
        total_pages INTEGER NOT NULL,
        start_number INTEGER NOT NULL,
        end_number INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE status_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cheque_id TEXT NOT NULL,
        from_status TEXT NOT NULL,
        to_status TEXT NOT NULL,
        changed_at TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (cheque_id) REFERENCES cheques (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_cheques_due_date ON cheques (due_date)');
    await db.execute('CREATE INDEX idx_cheques_status ON cheques (status)');
    await db.execute('CREATE INDEX idx_cheques_direction ON cheques (direction)');
    await db.execute('CREATE INDEX idx_cheques_archived ON cheques (is_archived)');
    await db.execute('CREATE INDEX idx_status_history_cheque_id ON status_history (cheque_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE cheques ADD COLUMN image_paths TEXT DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE cheques ADD COLUMN cheque_book_id TEXT");
      await db.execute("ALTER TABLE cheques ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cheque_books (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          bank_id TEXT NOT NULL,
          bank_name TEXT NOT NULL,
          branch TEXT NOT NULL,
          total_pages INTEGER NOT NULL,
          start_number INTEGER NOT NULL,
          end_number INTEGER NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE cheques ADD COLUMN counterparty_phone TEXT");
    }
  }

  // ---- Cheque CRUD ----

  Future<void> insertCheque(Map<String, dynamic> chequeMap) async {
    final db = await database;
    await db.insert('cheques', chequeMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCheque(Map<String, dynamic> chequeMap) async {
    final db = await database;
    await db.update(
      'cheques',
      chequeMap,
      where: 'id = ?',
      whereArgs: [chequeMap['id']],
    );
  }

  Future<void> deleteCheque(String id) async {
    final db = await database;
    await db.delete('cheques', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllCheques() async {
    final db = await database;
    return db.query('cheques', orderBy: 'due_date ASC');
  }

  Future<Map<String, dynamic>?> getChequeById(String id) async {
    final db = await database;
    final results =
    await db.query('cheques', where: 'id = ?', whereArgs: [id]);
    return results.isEmpty ? null : results.first;
  }

  Future<bool> sayyadiIdExists(String sayyadiId, {String? excludeId}) async {
    final db = await database;
    String where = 'sayyadi_id = ?';
    List<Object?> whereArgs = [sayyadiId];
    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    final results = await db.query('cheques',
        where: where, whereArgs: whereArgs, limit: 1);
    return results.isNotEmpty;
  }

  // ---- ChequeBook CRUD ----

  Future<void> insertChequeBook(Map<String, dynamic> map) async {
    final db = await database;
    await db.insert('cheque_books', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateChequeBook(Map<String, dynamic> map) async {
    final db = await database;
    await db.update('cheque_books', map,
        where: 'id = ?', whereArgs: [map['id']]);
  }

  Future<void> deleteChequeBook(String id) async {
    final db = await database;
    await db.delete('cheque_books', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllChequeBooks() async {
    final db = await database;
    return db.query('cheque_books', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getChequeBookById(String id) async {
    final db = await database;
    final results =
    await db.query('cheque_books', where: 'id = ?', whereArgs: [id]);
    return results.isEmpty ? null : results.first;
  }

  Future<List<Map<String, dynamic>>> getChequesForBook(String bookId) async {
    final db = await database;
    return db.query(
      'cheques',
      columns: ['id', 'cheque_number', 'counterparty_name', 'amount', 'status', 'due_date'],
      where: 'cheque_book_id = ?',
      whereArgs: [bookId],
      orderBy: 'cheque_number ASC',
    );
  }

  // ---- Status History ----

  Future<void> insertStatusChange(
      String chequeId, Map<String, dynamic> changeMap) async {
    final db = await database;
    await db.insert('status_history', {
      'cheque_id': chequeId,
      ...changeMap,
    });
  }

  Future<List<Map<String, dynamic>>> getStatusHistory(String chequeId) async {
    final db = await database;
    return db.query(
      'status_history',
      where: 'cheque_id = ?',
      whereArgs: [chequeId],
      orderBy: 'changed_at ASC',
    );
  }

  // ---- Search ----

  Future<List<Map<String, dynamic>>> searchCheques(String query) async {
    final db = await database;
    final q = '%$query%';
    final numericQuery = query.replaceAll(',', '').replaceAll('۰', '0')
        .replaceAll('۱', '1').replaceAll('۲', '2').replaceAll('۳', '3')
        .replaceAll('۴', '4').replaceAll('۵', '5').replaceAll('۶', '6')
        .replaceAll('۷', '7').replaceAll('۸', '8').replaceAll('۹', '9');
    final amountQ = '%$numericQuery%';
    return db.query(
      'cheques',
      where: '''
        sayyadi_id LIKE ? OR
        cheque_number LIKE ? OR
        bank_name LIKE ? OR
        counterparty_name LIKE ? OR
        counterparty_phone LIKE ? OR
        note LIKE ? OR
        tags LIKE ? OR
        CAST(amount AS TEXT) LIKE ?
      ''',
      whereArgs: [q, q, q, q, q, q, q, amountQ],
      orderBy: 'due_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getChequesNeedingAttention(
      int reminderDays) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = today.add(Duration(days: reminderDays));

    return db.query(
      'cheques',
      where: '''
        status NOT IN ('cleared', 'cancelled', 'returned') AND
        due_date <= ? AND
        is_archived = 0
      ''',
      whereArgs: [reminderDate.toIso8601String()],
      orderBy: 'due_date ASC',
    );
  }

  // ---- Settings ----

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return results.isEmpty ? null : results.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final results = await db.query('settings');
    return {
      for (final row in results) row['key'] as String: row['value'] as String
    };
  }
}

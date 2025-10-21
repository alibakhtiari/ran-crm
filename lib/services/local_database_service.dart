import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/contact.dart';
import '../models/call_log.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ran_crm.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced_at TEXT
      )
    ''');

    // Call logs table
    await db.execute('''
      CREATE TABLE call_logs (
        id INTEGER PRIMARY KEY,
        phone_number TEXT NOT NULL,
        call_type TEXT NOT NULL,
        duration INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        contact_name TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_contacts_phone ON contacts(phone_number)');
    await db.execute('CREATE INDEX idx_call_logs_phone ON call_logs(phone_number)');
    await db.execute('CREATE INDEX idx_call_logs_timestamp ON call_logs(timestamp)');
  }

  // ==================== CONTACTS ====================

  Future<List<Contact>> getContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return List.generate(maps.length, (i) {
      return Contact(
        id: maps[i]['id'] as int,
        name: maps[i]['name'] as String,
        phoneNumber: maps[i]['phone_number'] as String,
        createdByUserId: maps[i]['created_by_user_id'] as int,
        createdAt: DateTime.parse(maps[i]['created_at'] as String),
        updatedAt: maps[i]['updated_at'] != null
            ? DateTime.parse(maps[i]['updated_at'] as String)
            : null,
      );
    });
  }

  Future<Contact?> getContactByPhone(String phoneNumber) async {
    final db = await database;

    // Normalize phone number (remove spaces, dashes, etc.)
    final normalized = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      where: "REPLACE(REPLACE(REPLACE(REPLACE(phone_number, ' ', ''), '-', ''), '(', ''), ')', '') LIKE ?",
      whereArgs: ['%$normalized%'],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return Contact(
      id: maps[0]['id'] as int,
      name: maps[0]['name'] as String,
      phoneNumber: maps[0]['phone_number'] as String,
      createdByUserId: maps[0]['created_by_user_id'] as int,
      createdAt: DateTime.parse(maps[0]['created_at'] as String),
      updatedAt: maps[0]['updated_at'] != null
          ? DateTime.parse(maps[0]['updated_at'] as String)
          : null,
    );
  }

  Future<void> insertContact(Contact contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      {
        'id': contact.id,
        'name': contact.name,
        'phone_number': contact.phoneNumber,
        'created_by_user_id': contact.createdByUserId,
        'created_at': contact.createdAt.toIso8601String(),
        'updated_at': contact.updatedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertContacts(List<Contact> contacts) async {
    final db = await database;
    final batch = db.batch();

    for (final contact in contacts) {
      batch.insert(
        'contacts',
        {
          'id': contact.id,
          'name': contact.name,
          'phone_number': contact.phoneNumber,
          'created_by_user_id': contact.createdByUserId,
          'created_at': contact.createdAt.toIso8601String(),
          'updated_at': contact.updatedAt?.toIso8601String(),
          'synced_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> updateContact(Contact contact) async {
    final db = await database;
    await db.update(
      'contacts',
      {
        'name': contact.name,
        'phone_number': contact.phoneNumber,
        'updated_at': contact.updatedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> deleteContact(int id) async {
    final db = await database;
    await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearContacts() async {
    final db = await database;
    await db.delete('contacts');
  }

  // ==================== CALL LOGS ====================

  Future<List<CallLog>> getCallLogs({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'call_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return CallLog(
        id: maps[i]['id'] as int?,
        phoneNumber: maps[i]['phone_number'] as String,
        callType: maps[i]['call_type'] as String,
        duration: maps[i]['duration'] as int,
        timestamp: DateTime.parse(maps[i]['timestamp'] as String),
        userId: maps[i]['user_id'] as int,
        contactName: maps[i]['contact_name'] as String?,
        createdAt: DateTime.parse(maps[i]['created_at'] as String),
      );
    });
  }

  Future<void> insertCallLog(CallLog callLog) async {
    final db = await database;

    // Try to find contact name if not provided
    String? contactName = callLog.contactName;
    if (contactName == null) {
      final contact = await getContactByPhone(callLog.phoneNumber);
      contactName = contact?.name;
    }

    await db.insert(
      'call_logs',
      {
        'id': callLog.id,
        'phone_number': callLog.phoneNumber,
        'call_type': callLog.callType,
        'duration': callLog.duration,
        'timestamp': callLog.timestamp.toIso8601String(),
        'user_id': callLog.userId,
        'contact_name': contactName,
        'created_at': callLog.createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCallLogs(List<CallLog> callLogs) async {
    final db = await database;
    final batch = db.batch();

    for (final callLog in callLogs) {
      // Try to find contact name if not provided
      String? contactName = callLog.contactName;
      if (contactName == null) {
        final contact = await getContactByPhone(callLog.phoneNumber);
        contactName = contact?.name;
      }

      batch.insert(
        'call_logs',
        {
          'id': callLog.id,
          'phone_number': callLog.phoneNumber,
          'call_type': callLog.callType,
          'duration': callLog.duration,
          'timestamp': callLog.timestamp.toIso8601String(),
          'user_id': callLog.userId,
          'contact_name': contactName,
          'created_at': callLog.createdAt.toIso8601String(),
          'synced_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearCallLogs() async {
    final db = await database;
    await db.delete('call_logs');
  }

  // Update contact names in call logs (useful after syncing new contacts)
  Future<void> updateCallLogContactNames() async {
    final db = await database;
    final callLogs = await getCallLogs();

    final batch = db.batch();
    for (final callLog in callLogs) {
      final contact = await getContactByPhone(callLog.phoneNumber);
      if (contact != null && callLog.contactName != contact.name) {
        batch.update(
          'call_logs',
          {'contact_name': contact.name},
          where: 'id = ?',
          whereArgs: [callLog.id],
        );
      }
    }

    await batch.commit(noResult: true);
  }

  // ==================== UTILITY ====================

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('contacts');
    await db.delete('call_logs');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

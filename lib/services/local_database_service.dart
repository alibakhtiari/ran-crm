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
      version: 3, // Incremented version for missed call constraint fix
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Add migration support
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

    // Call logs table with UUID support and fixed direction constraint
    await db.execute('''
      CREATE TABLE call_logs (
        id INTEGER PRIMARY KEY,
        uuid TEXT UNIQUE NOT NULL,
        phone_number TEXT NOT NULL,
        call_type TEXT NOT NULL,
        direction TEXT CHECK(direction IN ('incoming', 'outgoing', 'missed')), -- Now includes missed calls
        duration INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        contact_name TEXT,
        user_email TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_contacts_phone ON contacts(phone_number)');
    await db.execute('CREATE INDEX idx_call_logs_phone ON call_logs(phone_number)');
    await db.execute('CREATE INDEX idx_call_logs_timestamp ON call_logs(timestamp)');
    await db.execute('CREATE INDEX idx_call_logs_uuid ON call_logs(uuid)');
    await db.execute('CREATE INDEX idx_call_logs_direction ON call_logs(direction)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2: Add UUID support
      try {
        // Add uuid column
        await db.execute('ALTER TABLE call_logs ADD COLUMN uuid TEXT');
        
        // Make uuid unique
        await db.execute('CREATE UNIQUE INDEX idx_call_logs_uuid ON call_logs(uuid)');
        
        // Add direction column if it doesn't exist
        try {
          await db.execute('ALTER TABLE call_logs ADD COLUMN direction TEXT');
        } catch (e) {
          // Column might already exist, ignore error
        }
        
        // Add user_email column if it doesn't exist
        try {
          await db.execute('ALTER TABLE call_logs ADD COLUMN user_email TEXT');
        } catch (e) {
          // Column might already exist, ignore error
        }
      } catch (e) {
        // If migration fails, recreate the table
        await _recreateCallLogsTable(db);
      }
    }
    
    if (oldVersion < 3) {
      // Migration from version 2 to 3: Fix direction constraint to include missed calls
      try {
        // Drop existing CHECK constraint by recreating the table with proper constraints
        await _updateDirectionConstraint(db);
      } catch (e) {
        // If migration fails, recreate the table
        print('Failed to update direction constraint, recreating table: $e');
        await _recreateCallLogsTable(db);
      }
    }
  }

  Future<void> _updateDirectionConstraint(Database db) async {
    // SQLite doesn't support ALTER TABLE DROP CONSTRAINT, so we need to recreate
    // But first, let's try to update existing NULL directions to 'incoming' to avoid constraint violations
    try {
      await db.execute("UPDATE call_logs SET direction = 'incoming' WHERE direction IS NULL");
    } catch (e) {
      print('Error updating NULL directions: $e');
    }
    
    // For SQLite, we can't easily modify CHECK constraints, so we recreate the table
    await _recreateCallLogsTable(db);
  }

  Future<void> _recreateCallLogsTable(Database db) async {
    // Backup existing data
    final List<Map<String, dynamic>> existingData = await db.query('call_logs');
    
    // Drop and recreate table with proper constraints
    await db.execute('DROP TABLE IF EXISTS call_logs');
    await db.execute('''
      CREATE TABLE call_logs (
        id INTEGER PRIMARY KEY,
        uuid TEXT UNIQUE NOT NULL,
        phone_number TEXT NOT NULL,
        call_type TEXT NOT NULL,
        direction TEXT CHECK(direction IN ('incoming', 'outgoing', 'missed')), -- Now includes missed calls
        duration INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        contact_name TEXT,
        user_email TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
    
    // Recreate indexes
    await db.execute('CREATE INDEX idx_call_logs_phone ON call_logs(phone_number)');
    await db.execute('CREATE INDEX idx_call_logs_timestamp ON call_logs(timestamp)');
    await db.execute('CREATE INDEX idx_call_logs_uuid ON call_logs(uuid)');
    await db.execute('CREATE INDEX idx_call_logs_direction ON call_logs(direction)');
    
    // Restore data with proper directions
    for (final record in existingData) {
      final uuid = record['uuid'] ?? 'temp_${record['id']}_${DateTime.now().millisecondsSinceEpoch}';
      String direction = record['direction'];
      
      // Ensure direction is valid
      if (direction.isEmpty || 
          !['incoming', 'outgoing', 'missed'].contains(direction)) {
        direction = _inferDirectionFromCallType(record['call_type']);
      }
      
      await db.insert('call_logs', {
        'id': record['id'],
        'uuid': uuid,
        'phone_number': record['phone_number'],
        'call_type': record['call_type'],
        'direction': direction,
        'duration': record['duration'],
        'timestamp': record['timestamp'],
        'user_id': record['user_id'],
        'contact_name': record['contact_name'],
        'user_email': record['user_email'],
        'created_at': record['created_at'],
        'synced_at': DateTime.now().toIso8601String(),
      });
    }
  }

  static String _inferDirectionFromCallType(String callType) {
    final type = callType.toLowerCase();
    if (type.contains('incoming') || type.contains('received')) return 'incoming';
    if (type.contains('outgoing') || type.contains('made')) return 'outgoing';
    if (type.contains('missed')) return 'missed';
    return 'incoming'; // Default
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

  Future<List<CallLog>> getCallLogs({int? limit, String? direction}) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (direction != null) {
      whereClause = 'direction = ?';
      whereArgs = [direction];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'call_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return CallLog(
        id: maps[i]['id'] as int?,
        uuid: maps[i]['uuid'] as String,
        phoneNumber: maps[i]['phone_number'] as String,
        callType: maps[i]['call_type'] as String,
        direction: maps[i]['direction'] as String?,
        duration: maps[i]['duration'] as int,
        timestamp: DateTime.parse(maps[i]['timestamp'] as String),
        userId: maps[i]['user_id'] as int,
        contactName: maps[i]['contact_name'] as String?,
        userEmail: maps[i]['user_email'] as String?,
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

    // Ensure direction is valid
    String direction = callLog.direction ?? 'incoming';
    if (!['incoming', 'outgoing', 'missed'].contains(direction)) {
      direction = 'incoming';
    }

    await db.insert(
      'call_logs',
      {
        'id': callLog.id,
        'uuid': callLog.uuid,
        'phone_number': callLog.phoneNumber,
        'call_type': callLog.callType,
        'direction': direction,
        'duration': callLog.duration,
        'timestamp': callLog.timestamp.toIso8601String(),
        'user_id': callLog.userId,
        'contact_name': contactName,
        'user_email': callLog.userEmail,
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

      // Ensure direction is valid
      String direction = callLog.direction ?? 'incoming';
      if (!['incoming', 'outgoing', 'missed'].contains(direction)) {
        direction = 'incoming';
      }

      batch.insert(
        'call_logs',
        {
          'id': callLog.id,
          'uuid': callLog.uuid,
          'phone_number': callLog.phoneNumber,
          'call_type': callLog.callType,
          'direction': direction,
          'duration': callLog.duration,
          'timestamp': callLog.timestamp.toIso8601String(),
          'user_id': callLog.userId,
          'contact_name': contactName,
          'user_email': callLog.userEmail,
          'created_at': callLog.createdAt.toIso8601String(),
          'synced_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // Check if a call log with UUID already exists
  Future<bool> callLogExists(String uuid) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'call_logs',
      columns: ['uuid'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Get call logs by UUID
  Future<CallLog?> getCallLogByUuid(String uuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'call_logs',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return CallLog(
      id: maps[0]['id'] as int?,
      uuid: maps[0]['uuid'] as String,
      phoneNumber: maps[0]['phone_number'] as String,
      callType: maps[0]['call_type'] as String,
      direction: maps[0]['direction'] as String?,
      duration: maps[0]['duration'] as int,
      timestamp: DateTime.parse(maps[0]['timestamp'] as String),
      userId: maps[0]['user_id'] as int,
      contactName: maps[0]['contact_name'] as String?,
      userEmail: maps[0]['user_email'] as String?,
      createdAt: DateTime.parse(maps[0]['created_at'] as String),
    );
  }

  Future<void> clearCallLogs() async {
    final db = await database;
    await db.delete('call_logs');
  }

  // Update contact names in call logs (useful after syncing new contacts)
  Future<void> updateCallLogContactNames() async {
    final db = await database;
    final callLogs = await getCallLogs(); // This will now fetch all call logs

    final batch = db.batch();
    for (final callLog in callLogs) {
      final contact = await getContactByPhone(callLog.phoneNumber);
      if (contact != null && callLog.contactName != contact.name) {
        batch.update(
          'call_logs',
          {'contact_name': contact.name},
          where: 'uuid = ?', // Use UUID instead of id
          whereArgs: [callLog.uuid],
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

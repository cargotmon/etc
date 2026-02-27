import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('etc.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // 🔥 [임시 추가] 기존 DB 파일을 완전히 삭제해서 초기화를 강제함
    //await deleteDatabase(path);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // ⭐ [추가] Hive 대체용 설정 테이블
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT 
      )
    ''');

    // 1. 공간 테이블 생성
    await db.execute('''
      CREATE TABLE loc (
        sn INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        user_email TEXT NOT NULL,
        loc1 TEXT NOT NULL,
        loc2 TEXT,
        memo TEXT,
        sync_yn TEXT DEFAULT 'N',
        del_yn TEXT DEFAULT 'N',
        create_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. 물건 테이블 생성
    await db.execute('''
      CREATE TABLE items (
        sn INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category TEXT,
        loc_sn INTEGER,
        owner_email TEXT NOT NULL,
        holder_email TEXT NOT NULL,
        ea INTEGER NOT NULL DEFAULT 1,
        buy_dttm TEXT,
        memo TEXT,
        img_path TEXT,
        del_yn TEXT DEFAULT 'N', -- 🗑️ 삭제 여부 추가
        sync_yn TEXT DEFAULT 'N',
        create_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (loc_sn) REFERENCES loc (sn) ON DELETE SET NULL
      )
    ''');

    // 3. 데일리 로그 테이블 추가 (오늘의 메모)
    await db.execute('''
      CREATE TABLE daily_logs (
        sn INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        userid TEXT NOT NULL,   -- 💡 MariaDB의 userid 대응
        date TEXT NOT NULL,
        memo TEXT,
        med_time1 TEXT,      -- 💊 추가: 약 복용 시간 (예: '14:30')
        med_time2 TEXT,      -- 💊 추가: 약 복용 시간 (예: '14:30')
        med_time3 TEXT,      -- 💊 추가: 약 복용 시간 (예: '14:30')
        weather TEXT,       -- (필요시 추가)
        mood TEXT,          -- (필요시 추가)
        expense_data TEXT,
        create_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(date, userid)
      )
    ''');

    // 지출 테이블
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_uuid TEXT NOT NULL, -- daily_logs의 uuid와 매칭
        item TEXT,
        price INTEGER,
        FOREIGN KEY(log_uuid) REFERENCES daily_logs(uuid) ON DELETE CASCADE
      )
    ''');

    // 4. 투두 리스트 테이블 추가 (나중에 대비)
    await db.execute('''
      CREATE TABLE todos (
        sn INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        is_done INTEGER DEFAULT 0, -- 0: 미완료, 1: 완료
        create_dttm TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 초기 데이터 (기본 위치)
    await db.insert('loc', {
      'uuid': const Uuid().v4(),
      'user_email': 'cargotmon@gmail.com',
      'loc1': '미지정',
      'loc2': '기본위치',
      'del_yn': 'N',
      'sync_yn': 'N'
    });
  }
  // del_yn TEXT DEFAULT 'N',

  // 모든 설정값 가져오기 (초기 로딩용)
  Future<List<Map<String, dynamic>>> getAllSettings() async {
    final db = await instance.database;
    return await db.query('app_settings');
  }

  // 특정 설정값 저장/수정
  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 모든 아이템과 해당 장소명을 JOIN해서 가져오기
  Future<List<Map<String, dynamic>>> getItemsWithLoc33() async {
    final db = await instance.database;
    return await db.rawQuery('''
        SELECT i.*, l.uuid AS loc_uuid, l.loc1, l.loc2 
        FROM items i 
        LEFT JOIN loc l ON i.loc_sn = l.sn
        WHERE i.del_yn = 'N' 
        ORDER BY i.create_dttm DESC
      ''');
  }
  Future<List<Map<String, dynamic>>> getItemsWithLoc() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT i.*, l.uuid AS loc_uuid, l.loc1, l.loc2 
      FROM items i 
      LEFT JOIN loc l ON i.loc_sn = l.sn
      WHERE (i.del_yn = 'N' OR i.del_yn IS NULL OR i.del_yn = '') -- 💡 기존 데이터 누락 방지
      ORDER BY i.create_dttm DESC
    ''');
  }

  // 장소 이름을 확인하여 있으면 연결, 없으면 생성 후 아이템 저장/수정
  Future<int> saveItemWithLocName({
    required Map<String, dynamic> itemData,
    required String locName,
  }) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // 1. 장소(loc) 처리
      final List<Map<String, dynamic>> existingLoc = await txn.query(
        'loc',
        where: 'loc1 = ?',
        whereArgs: [locName.trim()],
      );

      int locSn;
      if (existingLoc.isNotEmpty) {
        locSn = existingLoc.first['sn'];
      } else {
        locSn = await txn.insert('loc', {
          'uuid': const Uuid().v4(),
          'user_email': itemData['owner_email'],
          'loc1': locName.trim(),
          'sync_yn': 'N'
        });
      }

      // 2. 데이터 복사 및 sn 처리 (수정 시 UNIQUE 에러 방지)
      final Map<String, dynamic> finalData = Map<String, dynamic>.from(itemData);
      finalData['loc_sn'] = locSn;
      finalData['sync_yn'] = 'N'; // 변경 발생 시 미동기 상태로

      if (finalData.containsKey('sn') && finalData['sn'] != null) {
        // 수정(Update) 로직
        int sn = finalData['sn'];
        return await txn.update(
          'items',
          finalData,
          where: 'sn = ?',
          whereArgs: [sn],
        );
      } else {
        // 신규 저장(Insert) 로직
        if (finalData['uuid'] == null) finalData['uuid'] = const Uuid().v4();
        return await txn.insert('items', finalData);
      }
    });
  }

  // 서버로 보낼 미동기 아이템 리스트 추출
  Future<List<Map<String, dynamic>>> getUnsyncedItems() async {
    final db = await instance.database;
    return await db.query('items', where: 'sync_yn = ?', whereArgs: ['N']);
  }

  // 서버로 보낼 미동기 장소 리스트 추출
  Future<List<Map<String, dynamic>>> getUnsyncedLocations() async {
    final db = await instance.database;
    return await db.query('loc', where: 'sync_yn = ?', whereArgs: ['N']);
  }

  // 동기화 완료 마킹 (아이템)
  Future<void> markItemsAsSynced(List<String> uuids) async {
    final db = await instance.database;
    await db.update('items', {'sync_yn': 'Y'},
        where: 'uuid IN (${uuids.map((_) => '?').join(', ')})',
        whereArgs: uuids);
  }

  // 동기화 완료 마킹 (장소)
  Future<void> markLocsAsSynced(List<String> uuids) async {
    final db = await instance.database;
    await db.update('loc', {'sync_yn': 'Y'},
        where: 'uuid IN (${uuids.map((_) => '?').join(', ')})',
        whereArgs: uuids);
  }

  // --- 삭제 기능 ---
  Future<int> deleteItem(int sn) async {
    final db = await instance.database;
    return await db.delete('items', where: 'sn = ?', whereArgs: [sn]);
  }

  // 단순 아이템 저장 (기존 코드 호환용)
  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;

    // 맵을 수정 가능하도록 복사
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);

    // UUID가 없으면 생성
    if (data['uuid'] == null) data['uuid'] = const Uuid().v4();

    // DB에 insert
    return await db.insert('items', data);
  }

  // 특정 아이템 정보 업데이트 (sn 기준)
  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;

    // 맵 복사 후 수정
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    data['sync_yn'] = 'N'; // 수정 시 다시 미동기 상태로 변경

    return await db.update(
      'items',
      data,
      where: 'sn = ?',
      whereArgs: [data['sn']],
    );
  }

  // database_helper.dart 내 추가
  Future<int> deleteLocation(int sn) async {
    final db = await instance.database;
    return await db.update(
      'loc',
      {'del_yn': 'Y', 'sync_yn': 'N'},
      where: 'sn = ?',
      whereArgs: [sn],
    );
  }

  // 서버 데이터를 로컬 DB에 병합 (UUID 기준)
  Future<void> syncServerToLocal(List<dynamic> serverItems, List<dynamic> serverLocs) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. 장소(loc) 복구
      for (var loc in serverLocs) {
        await txn.insert(
          'loc',
          {...loc, 'sync_yn': 'Y'}, // 서버 데이터이므로 싱크 완료 상태로 저장
          conflictAlgorithm: ConflictAlgorithm.replace, // UUID 중복 시 덮어쓰기
        );
      }

      // 2. 물건(items) 복구
      for (var item in serverItems) {
        await txn.insert(
          'items',
          {...item, 'sync_yn': 'Y'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // 💡 [추가] 자동완성 및 조회를 위한 장소 목록 가져오기
  Future<List<Map<String, dynamic>>> getLocations() async {
    final db = await instance.database;
    return await db.query('loc', where: "del_yn = 'N'");
  }

}

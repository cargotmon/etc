import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:etc/server/control/database_helper.dart'; // 본인의 DatabaseHelper 경로에 맞게 수정하세요

class TileSettingsManager {
  static const List<String> allTileIds = [
    "weather", "emotion", "med1", "med2", "med3", "chagebu", "money", "habit"
  ];

  static const String _storageKey = "enabled_dashboard_tiles";
  static const String _nameKey = "custom_tile_names";

  // 1. 활성화된 타일 ID 리스트 가져오기
  static Future<List<String>> getEnabledTiles44(String userId) async { // userId 파라미터 추가
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_storageKey],
    );

    List<String> currentTiles;
    if (maps.isEmpty) {
      currentTiles = List.from(allTileIds);
    } else {
      try {
        currentTiles = List<String>.from(json.decode(maps.first['value']));
      } catch (e) {
        currentTiles = List.from(allTileIds);
      }
    }

    // 유저 아이디가 cargotmon인 경우에만 chagebu를 포함
    if (userId == 'cargotmon') {
      if (!currentTiles.contains('chagebu')) {
        currentTiles.add('chagebu');
      }
    } else {
      // cargotmon이 아니면 리스트에서 chagebu 제외
      currentTiles.removeWhere((id) => id == 'chagebu');
    }

    return currentTiles;
  }
  // 1. 활성화된 타일 ID 리스트 가져오기
  static Future<List<String>> getEnabledTiles() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_storageKey],
    );

    //gv.userId;

    if (maps.isEmpty) return List.from(allTileIds);

    try {
      return List<String>.from(json.decode(maps.first['value']));
    } catch (e) {
      return List.from(allTileIds);
    }
  }

  // 2. 타일 순서 및 활성화 저장
  static Future<void> saveEnabledTiles(List<String> enabledList) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'app_settings',
      {
        'key': _storageKey,
        'value': json.encode(enabledList),
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // 이미 있으면 덮어쓰기
    );
  }

  // 3. 커스텀 이름 맵 가져오기 { "med1": "비타민", "med2": "유산균" }
  static Future<Map<String, String>> getCustomNames() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_nameKey],
    );

    if (maps.isEmpty) return {};

    try {
      return Map<String, String>.from(json.decode(maps.first['value']));
    } catch (e) {
      return {};
    }
  }

  // 4. 특정 타일의 이름 저장하기
  static Future<void> saveCustomName(String id, String newName) async {
    final db = await DatabaseHelper.instance.database;
    final names = await getCustomNames();
    names[id] = newName;

    await db.insert(
      'app_settings',
      {
        'key': _nameKey,
        'value': json.encode(names),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

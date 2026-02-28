import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:etc/server/control/database_helper.dart'; // 본인의 경로에 맞게 수정하세요

class MemoService {
  final String userId;
  final String listUrl; // PHP 파일 경로 (get_all_daily_logs.php)

  MemoService({required this.userId, required this.listUrl});

  /// 🚀 MariaDB 서버 데이터를 로컬 SQLite로 전체 마이그레이션 및 동기화
  Future<bool> backupMariaToLocal() async {
    try {
      // 1. 서버 호출 (userid 파라미터 전달)
      final response = await http.get(Uri.parse('$listUrl?userid=$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['ErrorCode'] == 0) {
          List<dynamic> serverLogs = data['data'] ?? [];
          final db = await DatabaseHelper.instance.database;

          // 2. 트랜잭션 시작 (속도와 안정성 확보)
          await db.transaction((txn) async {
            for (var log in serverLogs) {
              // UUID가 없으면 새로 생성 (서버 PHP가 처리하지만 안전장치)
              String logUuid = log['uuid'] ?? const Uuid().v4();

              // 💡 med_time 파싱 (공백 기준 분배)
              List<String> times = (log['med_time'] ?? "")
                  .toString()
                  .split(RegExp(r'\s+'))
                  .where((s) => s.isNotEmpty)
                  .toList();

              // 3. 메인 로그 저장 (daily_logs 테이블)
              await txn.insert(
                'daily_logs',
                {
                  'uuid': logUuid,
                  'userid': userId,
                  'date': log['date'], // MariaDB의 'day' 컬럼이 'date'로 내려옴
                  'memo': log['memo'],
                  'med_time1': times.isNotEmpty ? times[0] : null,
                  'med_time2': times.length > 1 ? times[1] : null,
                  'med_time3': times.length > 2 ? times[2] : null,
                  'weather': log['weather'],
                  'mood': log['mood'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // 4. 지출 상세 데이터 저장 (expenses 테이블)
              if (log['expense_data'] != null && log['expense_data'].toString().isNotEmpty) {
                // 기존 데이터 삭제 후 교체
                await txn.delete('expenses', where: 'log_uuid = ?', whereArgs: [logUuid]);

                try {
                  List<dynamic> expenseItems = jsonDecode(log['expense_data']);
                  for (var exp in expenseItems) {
                    await txn.insert('expenses', {
                      'log_uuid': logUuid,
                      'item': exp['item'],
                      'price': int.tryParse(exp['price'].toString()) ?? 0,
                    });
                  }
                } catch (e) {
                  print("지출 파싱 에러 (${log['date']}): $e");
                }
              }
            }
          });
          return true; // 성공
        }
      }
      return false;
    } catch (e) {
      print("마이그레이션 실패: $e");
      return false;
    }
  }

  /// 🚀 로컬 SQLite에서 전체 로그 조회 (타임라인용)
  Future<List<Map<String, dynamic>>> fetchLocalLogs() async {
    final db = await DatabaseHelper.instance.database;

    //userId = "";
    final data = await db.query('daily_logs',
        //where: 'userid = ?',
        //whereArgs: [userId],
        orderBy: 'date DESC'
    );

    debugPrint("🔎 로컬 DB 조회 결과: ${data.length}건 발견");

    return data;
  }
}
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:etc/server/model/item_model.dart';
import 'package:etc/server/control/database_helper.dart'; // DB 헬퍼 연결 필요

import 'package:etc/ui/screen/items/item_add_screen.dart';
import 'package:etc/ui/screen/items/item_edit_screen.dart';
import 'package:http/http.dart' as http; // 상단 추가
import 'dart:convert';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  List<Map<String, dynamic>> itemsData = []; // JOIN 쿼리 결과를 담을 리스트

  @override
  void initState() {
    super.initState();
    _refreshItems(); // 앱 시작 시 데이터 불러오기
  }

  // 🔄 DB에서 데이터를 새로 읽어오는 함수
  Future<void> _refreshItems() async {
    // JOIN 쿼리가 포함된 getItemsWithLoc 호출
    final data = await DatabaseHelper.instance.getItemsWithLoc();
    setState(() {
      itemsData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 물건 리스트'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshItems,
          ),
          IconButton(
            icon: const Icon(Icons.one_k_rounded),
            onPressed: pullFromServer,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            // onPressed: () async {
            //   // 1. 알림 표시
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     const SnackBar(content: Text('데이터 동기화를 시작합니다...')),
            //   );
            //
            //   try {
            //     // 2. 싱크 안 된 데이터들 가져오기
            //     final unsynced = await DatabaseHelper.instance.getUnsyncedItems();
            //
            //     if (unsynced.isEmpty) {
            //       if (!mounted) return;
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text('동기화할 새 데이터가 없습니다.')),
            //       );
            //       return;
            //     }
            //
            //     // 3. [여기에 나중에 http.post 서버 전송 로직이 들어갑니다]
            //     // 지금은 성공했다고 가정하고 로컬 상태만 'Y'로 바꿉니다.
            //     List<String> syncedUuids = unsynced.map((e) => e['uuid'] as String).toList();
            //     await DatabaseHelper.instance.markAsSynced(syncedUuids);
            //
            //     // 4. 화면 리스트 갱신 (아이콘 색상 등이 바뀔 수 있음)
            //     _refreshItems();
            //
            //     if (!mounted) return;
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       SnackBar(content: Text('${syncedUuids.length}개의 데이터를 서버와 동기화했습니다!')),
            //     );
            //   } catch (e) {
            //     debugPrint('싱크 에러: $e');
            //   }
            // },
            onPressed: () async {
              final unsyncedItems = await DatabaseHelper.instance.getUnsyncedItems();
              final unsyncedLocs = await DatabaseHelper.instance.getUnsyncedLocations();

              if (unsyncedItems.isEmpty && unsyncedLocs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('동기화할 새 데이터가 없습니다.')));
                return;
              }

              try {
                  // 🌍 1. 진짜 내 서버 주소로 전송!
                  final response = await http.post(
                  Uri.parse('https://lsj.kr/nexa/sync_item_data.php'), // 내 서버 주소
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'userid': 'coxycat@naver.com',
                    'items': unsyncedItems,
                    'locs': unsyncedLocs,
                  }), // 데이터를 JSON으로 변환
                );

                if (response.statusCode == 200) {
                  // ✅ 2. 서버가 "잘 받았어!"라고 응답(200)했을 때만 로컬을 'Y'로 변경
                  List<String> syncedUuids = unsyncedItems.map((e) => e['uuid'] as String).toList();
                  await DatabaseHelper.instance.markItemsAsSynced(syncedUuids);

                  _refreshItems();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버 동기화 성공!')));
                } else {
                  // ❌ 3. 서버 에러 발생 시
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버 응답 에러...')));
                }

              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
              }
            },
    ),
        ],
      ),
      body: itemsData.isEmpty
          ? const Center(
        child: Text(
          '등록된 물건이 없습니다.\n아래 + 버튼을 눌러 추가해보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: itemsData.length,
        itemBuilder: (context, index) {
          final row = itemsData[index];
          // Map 데이터를 모델로 변환
          final item = ItemModel.fromMap(row);

          // JOIN으로 가져온 장소명 (loc1, loc2)
          final String locationName = row['loc1'] ?? "미지정";
          final String subLocation = row['loc2'] != null && row['loc2'].toString().isNotEmpty
              ? " > ${row['loc2']}"
              : "";

          final bool isRented = item.ownerEmail != item.holderEmail;

          return Dismissible(
            key: Key(item.uuid),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.redAccent,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await _showDeleteConfirmDialog();
            },
            onDismissed: (direction) async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('items', where: 'sn = ?', whereArgs: [item.sn]);
              _refreshItems();
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              child: ListTile(
                onTap: () async {
                  // 수정 화면으로 이동
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ItemEditScreen(item: item)),
                  );
                  if (result == true) _refreshItems();
                },
                leading: CircleAvatar(
                  backgroundColor: _getCategoryColor(item.category),
                  child: Icon(_getCategoryIcon(item.category), color: Colors.white),
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.memo != null && item.memo!.isNotEmpty)
                      Text(item.memo!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$locationName$subLocation',
                            style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item.ea}ea', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (isRented)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('대여중', style: TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ItemAddScreen()),
          );
          if (result == true) _refreshItems();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 🗑️ 삭제 확인 팝업
  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 물건을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // 🎨 카테고리별 아이콘/컬러 매칭
  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '발통': return Icons.directions_car;
      case '집': return Icons.home;
      case '전동공구': return Icons.build;
      default: return Icons.inventory_2;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '발통': return Colors.blue;
      case '집': return Colors.green;
      case '전동공구': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  Future<void> pullFromServer() async {
    final box = Hive.box('settings');
    final String email = box.get('user_email', defaultValue: "");
    //print("email: $email");
    try {
      // 1. 서버에 내 이메일로 저장된 모든 데이터 요청
      //https://lsj.kr/nexa/sync_item_get_db.php?userid=coxycat@naver.com
      final response = await http.get(
        Uri.https('lsj.kr','/nexa/sync_item_get_db.php',{
          'userid': email,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 2. 로컬 DB에 들이붓기
        await DatabaseHelper.instance.syncServerToLocal(
          data['items'] ?? [],
          data['locs'] ?? [],
        );

        _refreshItems(); // 리스트 갱신
        debugPrint("데이터 복구 완료!");
      }
    } catch (e) {
      debugPrint("복구 실패: $e");
    }
  }

}

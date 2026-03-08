import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etc/server/control/database_helper.dart';

class MemoMonthPage extends StatefulWidget {
  final String userId;
  const MemoMonthPage({super.key, required this.userId});

  @override
  State<MemoMonthPage> createState() => _MemoMonthPageState();
}

class _MemoMonthPageState extends State<MemoMonthPage> {
  List<Map<String, dynamic>> _memoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMemos();
  }

  Future<void> _loadAllMemos() async {
    final db = await DatabaseHelper.instance.database;
    // 메모가 있는 데이터만 최신순으로 가져옴
    final res = await db.query(
      "daily_logs",
      where: "userid = ? AND memo IS NOT NULL AND memo != ''",
      whereArgs: [widget.userId],
      orderBy: "date DESC",
    );

    setState(() {
      _memoList = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("생각 모아보기", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : _memoList.isEmpty
          ? const Center(child: Text("기록된 메모가 없습니다.", style: TextStyle(color: Colors.white24)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _memoList.length,
        itemBuilder: (context, index) {
          final item = _memoList[index];
          final String dateStr = item['date']; // yyyy-MM-dd
          final DateTime date = DateTime.parse(dateStr);

          // 월 구분자 표시 여부 결정 (첫 아이템이거나 이전 아이템과 월이 다를 때)
          bool showHeader = false;
          if (index == 0) {
            showHeader = true;
          } else {
            final prevDate = DateTime.parse(_memoList[index - 1]['date']);
            if (prevDate.month != date.month || prevDate.year != date.year) {
              showHeader = true;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                  child: Text(
                    DateFormat('yyyy년 MM월').format(date),
                    style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MM월 dd일 E요일', 'ko_KR').format(date),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['memo'] ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

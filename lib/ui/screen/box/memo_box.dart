import 'package:etc/ui/screen/all_memo/memo_month.dart';
import 'package:etc/ui/screen/all_memo/memo_month_and_etc.dart';
import 'package:flutter/material.dart';
import 'package:etc/server/control/database_helper.dart';
import 'package:uuid/uuid.dart';

class MemoBox extends StatefulWidget {
  final String userId;
  final String date;

  const MemoBox({
    super.key,
    required this.userId,
    required this.date,
  });

  @override
  State<MemoBox> createState() => _MemoBoxState();
}

class _MemoBoxState extends State<MemoBox> {
  String sMemo = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMemo();
  }

  @override
  void didUpdateWidget(covariant MemoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.userId != widget.userId) {
      setState(() => isLoading = true);
      loadMemo();
    }
  }

  // 1. 메모 불러오기
  Future<void> loadMemo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        "daily_logs",
        columns: ["memo"],
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
      );

      if (result.isNotEmpty) {
        setState(() {
          sMemo = result.first["memo"]?.toString() ?? "";
          isLoading = false;
        });
      } else {
        setState(() {
          sMemo = "";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [MemoBox] 로드 에러: $e");
      setState(() => isLoading = false);
    }
  }

  // 2. 메모 저장하기
  Future<void> saveMemo(String val) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final exists = await db.query(
        "daily_logs",
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
      );

      if (exists.isEmpty) {
        await db.insert("daily_logs", {
          "uuid": const Uuid().v4(),
          "userid": widget.userId,
          "date": widget.date,
          "memo": val,
        });
      } else {
        await db.update(
          "daily_logs",
          {"memo": val},
          where: "userid=? AND date=?",
          whereArgs: [widget.userId, widget.date],
        );
      }
      setState(() => sMemo = val);
      debugPrint("📝 [MemoBox] 메모 저장 완료");
    } catch (e) {
      debugPrint("❌ [MemoBox] 저장 에러: $e");
    }
  }

  // 3. 수정 다이얼로그
  void showEditDialog() {
    TextEditingController c = TextEditingController(text: sMemo);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: GestureDetector(
          onTap: () {
            Navigator.pop(ctx); // 다이얼로그 닫고
            // MemoMonthPage
            Navigator.push(context, MaterialPageRoute(builder: (context) => MemoMonthPage_ETC(userId: widget.userId)));
          },
          child: const Row(
            children: [
              Text("📝 오늘의 생각 기록>"),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite, // 다이얼로그 가로 꽉 차게
          child: TextField(
            controller: c,
            maxLines: 10, // 입력창 높이 상향 조정
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "오늘 어떤 일이 있었나요?\n내용을 입력해주세요.",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(
            onPressed: () async {
              await saveMemo(c.text);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("저장"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ 색상 로직: 값이 있으면 PinkAccent, 없으면 Grey
    final bool hasValue = sMemo.isNotEmpty;
    final Color activeColor = hasValue ? Colors.pinkAccent : Colors.grey;

    return GestureDetector(
      onTap: showEditDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // 배경색 투명도: 값이 있을 때 더 강조
          color: activeColor.withOpacity(hasValue ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue ? activeColor.withOpacity(0.4) : Colors.white10,
          ),
        ),
        child: isLoading
            ? const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    Icons.edit_note,
                    color: hasValue ? activeColor : Colors.white38,
                    size: 22
                ),
                const SizedBox(width: 8),
                Text(
                    "오늘의 생각",
                    style: TextStyle(
                      color: hasValue ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sMemo.isEmpty ? "터치하여 메모를 남겨보세요." : sMemo,
              style: TextStyle(
                // 내용이 있으면 흰색, 없으면 흐릿한 회색
                color: hasValue ? Colors.white.withOpacity(0.9) : Colors.white24,
                fontSize: 15,
                height: 1.5,
              ),
              // 대시보드에서 너무 길어지지 않게 적절히 제한 (필요시 조절)
              maxLines: 500,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

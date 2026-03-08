import 'package:flutter/material.dart';
import 'package:etc/server/control/database_helper.dart';
import 'package:uuid/uuid.dart';

class MoodBox extends StatefulWidget {
  final String userId;
  final String date;

  const MoodBox({
    super.key,
    required this.userId,
    required this.date,
  });

  @override
  State<MoodBox> createState() => _MoodBoxState();
}

class _MoodBoxState extends State<MoodBox> {
  String mood = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMood();
  }

  @override
  void didUpdateWidget(covariant MoodBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.userId != widget.userId) {
      setState(() => isLoading = true);
      loadMood();
    }
  }

  Future<void> loadMood() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        "daily_logs",
        columns: ["mood"],
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
      );

      if (result.isNotEmpty) {
        setState(() {
          mood = result.first["mood"]?.toString() ?? "";
          isLoading = false;
        });
      } else {
        setState(() {
          mood = "";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [MoodBox] 조회 에러: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> saveMood(String val) async {
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
          "mood": val,
        });
      } else {
        await db.update(
          "daily_logs",
          {"mood": val},
          where: "userid=? AND date=?",
          whereArgs: [widget.userId, widget.date],
        );
      }
      setState(() => mood = val);
    } catch (e) {
      debugPrint("❌ [MoodBox] 저장 에러: $e");
    }
  }

  IconData getMoodIcon(String moodText) {
    if (moodText.isEmpty) return Icons.sentiment_neutral;
    if (moodText.contains('좋음') || moodText.contains('행복')) return Icons.sentiment_very_satisfied;
    if (moodText.contains('슬픔') || moodText.contains('우울')) return Icons.sentiment_very_dissatisfied;
    if (moodText.contains('화') || moodText.contains('분노')) return Icons.sentiment_dissatisfied;
    if (moodText.contains('보통')) return Icons.sentiment_satisfied;
    return Icons.sentiment_satisfied_alt;
  }

  void showEditDialog() {
    TextEditingController c = TextEditingController(text: mood);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("감정 상태 입력"),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: "예: 좋음, 슬픔, 보통")
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(
            onPressed: () async {
              await saveMood(c.text);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ 데이터 유무에 따른 색상 로직 적용
    final bool hasValue = mood.isNotEmpty;
    final Color activeColor = hasValue ? Colors.pinkAccent : Colors.grey;

    return GestureDetector(
      onTap: showEditDialog,
      child: Container(
        decoration: BoxDecoration(
          // 배경: 값이 있으면 핑크빛, 없으면 아주 연한 회색
          color: activeColor.withOpacity(hasValue ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue ? activeColor.withOpacity(0.5) : Colors.white10,
          ),
        ),
        child: isLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                getMoodIcon(mood),
                color: activeColor, // 아이콘도 유무에 따라 색상 변경
                size: 28
            ),
            const SizedBox(height: 6),
            Text(
                "감정",
                style: TextStyle(
                    color: hasValue ? Colors.white70 : Colors.white38,
                    fontSize: 10
                )
            ),
            const SizedBox(height: 2),
            Text(
              mood.isEmpty ? "입력필요" : mood,
              style: TextStyle(
                  color: hasValue ? activeColor : Colors.white24,
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }
}

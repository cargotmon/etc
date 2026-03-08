import 'package:flutter/material.dart';
import 'package:etc/server/control/database_helper.dart';
import 'package:uuid/uuid.dart';

class WeatherTile extends StatefulWidget {
  final String userId;
  final String date;

  const WeatherTile({
    super.key,
    required this.userId,
    required this.date,
  });

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile> {
  String weather = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint("🔍 [WeatherTile] 초기화됨 - userId: ${widget.userId}, date: ${widget.date}");
    loadWeather();
  }

  @override
  void didUpdateWidget(covariant WeatherTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 날짜나 사용자가 변경되면 데이터를 새로 불러옴
    if (oldWidget.date != widget.date || oldWidget.userId != widget.userId) {
      debugPrint("📅 [WeatherTile] 변경 감지: ${oldWidget.date} -> ${widget.date}");
      setState(() => isLoading = true);
      loadWeather();
    }
  }

  Future<void> loadWeather() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        "daily_logs",
        columns: ["weather"],
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
      );

      if (result.isNotEmpty) {
        setState(() {
          weather = result.first["weather"]?.toString() ?? "";
          isLoading = false;
        });
      } else {
        setState(() {
          weather = "";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [WeatherTile] 로드 에러: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> saveWeather(String val) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> exists = await db.query(
        "daily_logs",
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
      );

      if (exists.isEmpty) {
        await db.insert("daily_logs", {
          "uuid": const Uuid().v4(),
          "userid": widget.userId,
          "date": widget.date,
          "weather": val,
        });
      } else {
        await db.update(
          "daily_logs",
          {"weather": val},
          where: "userid=? AND date=?",
          whereArgs: [widget.userId, widget.date],
        );
      }

      setState(() {
        weather = val;
      });
    } catch (e) {
      debugPrint("❌ [WeatherTile] 저장 에러: $e");
    }
  }

  IconData getWeatherIcon(String weatherText) {
    if (weatherText.isEmpty) return Icons.add_circle_outline; // 값이 없을 때 아이콘
    if (weatherText.contains('비') || weatherText.contains('흐림')) return Icons.umbrella;
    if (weatherText.contains('춥') || weatherText.contains('겨울')) return Icons.ac_unit;
    if (weatherText.contains('맑음')) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  void showEditDialog() {
    TextEditingController c = TextEditingController(text: weather);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("날씨 입력"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: "오늘 날씨는 어떤가요?"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(
            onPressed: () async {
              await saveWeather(c.text);
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
    // ⭐ 색상 로직 수정: 값이 있으면 OrangeAccent, 없으면 Grey
    final bool hasValue = weather.isNotEmpty;
    final Color activeColor = hasValue ? Colors.orangeAccent : Colors.grey;

    return GestureDetector(
      onTap: showEditDialog,
      child: Container(
        decoration: BoxDecoration(
          // 배경색 투명도 조절 (0.05 -> 0.1)
          color: activeColor.withOpacity(hasValue ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue ? activeColor.withOpacity(0.5) : Colors.white10,
            width: 1,
          ),
        ),
        child: isLoading
            ? const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              getWeatherIcon(weather),
              // 아이콘 색상은 투명도를 주지 않아야 회색/오렌지색 구분이 확실함
              color: activeColor,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              "날씨",
              style: TextStyle(
                color: hasValue ? Colors.white70 : Colors.white38,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              weather.isEmpty ? "입력필요" : weather,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // 입력 전엔 흐릿한 회색글씨, 입력 후엔 강조된 색상
                color: hasValue ? activeColor : Colors.white24,
                fontSize: 13,
                fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

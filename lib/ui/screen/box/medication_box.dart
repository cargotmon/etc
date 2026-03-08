import 'package:flutter/material.dart';
import 'package:etc/server/control/database_helper.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uuid/uuid.dart';
// ⭐ 추가: 설정 매니저 임포트
import 'package:etc/ui/screen/setting/tile_settings_manager.dart';

class MedicationBox extends StatefulWidget {
  final String userId;
  final String date;
  final String id; // "med1", "med2", "med3"
  final String title; // ⭐ 이름을 외부에서 주입받음


  const MedicationBox({
    super.key,
    required this.userId,
    required this.date,
    required this.id,
    this.title = "약 복용", //required this.title, // ⭐ 필수값 추가
  });

  @override
  State<MedicationBox> createState() => _MedicationBoxState();
}

class _MedicationBoxState extends State<MedicationBox> {
  String medTime = "";
  String customTitle = ""; // ⭐ 추가: 커스텀 타이틀 저장 변수
  bool isLoading = true;

  String get column {
    if (widget.id == "med2") return "med_time2";
    if (widget.id == "med3") return "med_time3";
    return "med_time1";
  }

  Color get activeColor {
    if (widget.id == "med1") return Colors.cyanAccent;
    if (widget.id == "med2") return Colors.orangeAccent;
    if (widget.id == "med3") return Colors.lightGreenAccent;
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didUpdateWidget(covariant MedicationBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.id != widget.id) {
      setState(() => isLoading = true);
      _loadAllData();
    }
  }

  // ⭐ 통합 로드 함수 (시간 + 커스텀 명칭)
  Future<void> _loadAllData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. 복용 시간 조회
      final result = await db.query(
        "daily_logs",
        columns: [column],
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
      );

      // 2. 커스텀 명칭 조회
      final names = await TileSettingsManager.getCustomNames();

      // 기본 이름 설정 (커스텀 이름이 없으면 '약 1' 등 기본값 사용)
      String defaultName = "약 ${widget.id.replaceAll('med', '')}";

      setState(() {
        medTime = result.isNotEmpty ? (result.first[column]?.toString() ?? "") : "";
        customTitle = names[widget.id] ?? defaultName; // ⭐ 이름 적용
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> handleSave333() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final exists = await db.query("daily_logs",
          where: "userid=? AND date=?", whereArgs: [widget.userId, widget.date]);

      if (exists.isEmpty) {
        await db.insert("daily_logs", {
          "uuid": const Uuid().v4(),
          "userid": widget.userId,
          "date": widget.date,
          column: medTime,
        });
      } else {
        await db.update("daily_logs", {column: medTime},
            where: "userid=? AND date=?", whereArgs: [widget.userId, widget.date]);
      }
    } catch (e) {
      debugPrint("❌ [MedicationBox] 저장 에러: $e");
    }
  }
  // 데이터베이스 저장 및 홈 위젯 동기화 로직
  Future<void> handleSave() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final exists = await db.query("daily_logs",
          where: "userid=? AND date=?", whereArgs: [widget.userId, widget.date]);

      // 1. DB 업데이트
      if (exists.isEmpty) {
        await db.insert("daily_logs", {
          "uuid": const Uuid().v4(),
          "userid": widget.userId,
          "date": widget.date,
          column: medTime,
        });
      } else {
        await db.update("daily_logs", {column: medTime},
            where: "userid=? AND date=?", whereArgs: [widget.userId, widget.date]);
      }

      // 2. ⭐ 홈 위젯 데이터 업데이트 (med1인 경우에만 혹은 공통으로)
      // 여기서는 예시로 med1일 때 'med_time' 키로 위젯에 전송합니다.
      if (widget.id == "med1") {
        final String displayTime = medTime.isEmpty ? "--:--" : medTime;

        await HomeWidget.saveWidgetData<String>('med_time', displayTime);
        await HomeWidget.saveWidgetData<String>(
            'last_update_date',
            DateTime.now().toString().split(' ')[0]
        );

        await HomeWidget.updateWidget(
          name: 'HomeWidgetProvider',
          androidName: 'HomeWidgetProvider',
        );
        debugPrint("🏠 [HomeWidget] 위젯 데이터 동기화 완료: $displayTime");
      }

    } catch (e) {
      debugPrint("❌ [MedicationBox] 저장 및 위젯 업데이트 에러: $e");
    }
  }

  String _getNowTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void handleTap() async {
    if (medTime.isEmpty) {
      final nowStr = _getNowTime();
      setState(() => medTime = nowStr);
      await handleSave();
    } else {
      showActionDialog();
    }
  }

  Future<String?> _pickTime(BuildContext context, String initial) async {
    int initialHour = TimeOfDay.now().hour;
    int initialMinute = TimeOfDay.now().minute;
    if (initial.contains(":")) {
      final parts = initial.split(":");
      initialHour = int.parse(parts[0]);
      initialMinute = int.parse(parts[1]);
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (picked != null) {
      return "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    }
    return null;
  }

  void showActionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("💊 $customTitle 기록 관리"), // ⭐ 이름 반영
        content: Text("현재 기록된 시간: $medTime\n기록을 관리하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => medTime = "");
              await handleSave();
            },
            child: const Text("기록 삭제", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final String? picked = await _pickTime(context, medTime);
              if (picked != null) {
                setState(() => medTime = picked);
                await handleSave();
              }
            },
            child: const Text("시간 수정"),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: handleTap,
      child: Container(
        decoration: BoxDecoration(
          color: activeColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: medTime.isEmpty ? Colors.white10 : activeColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: isLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              medTime.isEmpty ? Icons.medication_outlined : Icons.medication_liquid,
              color: medTime.isEmpty ? Colors.white30 : activeColor,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              //customTitle, // ⭐ '약 1' 대신 '비타민' 등 커스텀 명칭 표시
              widget.title, // ⭐ 생성자로 받은 타이틀을 그대로 출력
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              medTime.isEmpty ? "미복용" : medTime,
              style: TextStyle(
                color: medTime.isEmpty ? Colors.white24 : activeColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

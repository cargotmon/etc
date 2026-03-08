import 'package:etc/ui/screen/box/memo_box.dart';
import 'package:etc/ui/screen/box/money_box.dart';
import 'package:etc/ui/screen/box/mood_box.dart';
import 'package:flutter/material.dart';
import 'package:etc/ui/screen/box/weather_box.dart';

import 'box/medication_box.dart';

class DashboardTile {
  final String id;
  final String title;     // 일반 타일용 (Weather일 땐 빈값 가능)
  final IconData? icon;   // 일반 타일용 (Weather일 땐 null 가능)
  final dynamic page; // Widget 혹은 String(라우터명)
  final Widget? child;    // <--- WeatherTile 등을 담을 곳
  final VoidCallback? onTap;

  const DashboardTile({
    required this.id,
    this.title = "",
    this.icon,
    this.page,
    this.child,
    this.onTap,
  });
}

IconData getWeatherIcon(String weatherText) {
  if (weatherText.contains('비') || weatherText.contains('흐림')) {
    return Icons.umbrella; // 비 관련 아이콘
  } else if (weatherText.contains('춥') || weatherText.contains('추움') || weatherText.contains('겨울')) {
    return Icons.ac_unit; // 추위/눈 관련 아이콘
  } else if (weatherText.contains('맑음') || weatherText.contains('좋음') || weatherText.contains('햇빛')) {
    return Icons.wb_sunny; // 맑음 아이콘
  } else {
    return Icons.wb_cloudy; // 기본값 (구름 등)
  }
}
// [팝업] 수정 다이얼로그
void showEditDialog(BuildContext context, String type, String currentVal, Function(String) onSave) {
  TextEditingController c = TextEditingController(text: currentVal);
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: Text("$type 입력"),
    content: TextField(controller: c, maxLines: type == "메모" ? 5 : 1),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
      ElevatedButton(onPressed: () { onSave(c.text); Navigator.pop(ctx); }, child: const Text("확인")),
    ],
  ));
}
String sWeather = "";

class DashboardTileFactory {
  static List<DashboardTile> buildTiles({
    required BuildContext context,
    required String userId,
    required String date,
    required List<String> enabledTiles,      // 저장된 순서 리스트
    required Map<String, String> customNames, // 저장된 커스텀 명칭 맵
  }) {
    // 1. 우선 모든 타일의 "생성 로직"을 맵 형태로 준비합니다.
    final Map<String, DashboardTile> tileDefinitions = {
      "weather": DashboardTile(
        id: "weather",
        title: customNames["weather"] ?? "날씨",
        icon: Icons.wb_sunny,
        child: WeatherTile(userId: userId, date: date),
      ),
      "emotion": DashboardTile(
        id: "emotion",
        title: customNames["emotion"] ?? "감정",
        icon: Icons.favorite,
        child: MoodBox(userId: userId, date: date),
      ),
      "med1": DashboardTile(
        id: "med1",
        title: customNames["med1"] ?? "약 먹기",
        icon: Icons.medication_liquid,
        child: MedicationBox(userId: userId, date: date, id: "med1", title: customNames["med1"] ?? "아침 약"),
      ),
      "med2": DashboardTile(
        id: "med2",
        title: customNames["med2"] ?? "약 먹기",
        icon: Icons.medication_liquid,
        child: MedicationBox(userId: userId, date: date, id: "med2", title: customNames["med2"] ?? "점심 약"),
      ),
      "med3": DashboardTile(
        id: "med3",
        title: customNames["med3"] ?? "약 먹기",
        icon: Icons.medication_liquid,
        child: MedicationBox(userId: userId, date: date, id: "med3", title: customNames["med3"] ?? "저녁 약"),
      ),
      "chagebu": DashboardTile(
        id: "chagebu",
        title: customNames["chagebu"] ?? "차계부",
        icon: Icons.motorcycle_rounded,
        page: "/car_view",
      ),
      "money": DashboardTile(
        id: "money",
        title: customNames["money"] ?? "지출", // MoneyBox 내부 타이틀용
        child: MoneyBox(userId: userId, date: date),
      ),
      "habit": DashboardTile(
        id: "habit",
        title: customNames["habit"] ?? "물건들",
        icon: Icons.repeat,
        page: "/item_view",
      ),
      // "memo": DashboardTile(
      //   id: "memo",
      //   title: customNames["memo"] ?? "메모",
      //   child: MemoBox(userId: userId, date: date),
      // ),
    };

    // 2. 핵심: 사용자가 설정한 순서(enabledTiles)대로 리스트를 재구성합니다.
    return enabledTiles
        .where((id) => tileDefinitions.containsKey(id)) // 정의된 ID만 필터링
        .map((id) => tileDefinitions[id]!)             // 순서대로 타일 객체 매핑
        .toList();
  }
}

class DashboardTileFactory_bak {
  static List<DashboardTile> buildTiles({
    required BuildContext context,
    required String userId,
    required String date,
    required List<String> enabledTiles // <--- 활성화된 ID 리스트 전달받음
  }) {
    // 1. 모든 타일 정의
    final allTiles = [
      DashboardTile(
        id: "weather",
        title: "날씨",
        icon: Icons.favorite,
        child: WeatherTile(userId: userId, date: date),
      ),

      DashboardTile(
        id: "emotion",
        title: "감정",
        icon: Icons.favorite,
        child: MoodBox(userId: userId, date: date),
      ),

      DashboardTile(
        id: "med1",
        title: "약 먹기",
        icon: Icons.medication_liquid,
        child: MedicationBox(userId: userId, date: date, id: "med1", title: "3"),
      ),

      DashboardTile(
        id: "med2",
        title: "약 먹기",
        icon: Icons.medication_liquid,
        child: MedicationBox(userId: userId, date: date, id: "med2", title: "2"),
      ),

      DashboardTile(
        id: "med3",
        title: "약 먹기",
        icon: Icons.medication_liquid,
        child: MedicationBox(userId: userId, date: date, id: "med3", title: "1"),
      ),

      DashboardTile(
        id: "chagebu",
        title: "차계부",
        icon: Icons.motorcycle_rounded,
        page: "/car_view",
      ),

      //'/car_view': (context) => const CarEfficiencyView(),
      DashboardTile(
        id: "money",
        child: MoneyBox(userId: userId, date: date),
      ),

      // DashboardTile(
      //   id: "todo",
      //   title: "할일",
      //   icon: Icons.check_circle,
      //   page: Container(),
      // ),
      //
      // DashboardTile(
      //   id: "memo",
      //   title: "메모",
      //   icon: Icons.note,
      //   page: Container(),
      // ),

      DashboardTile(
        id: "habit",
        title: "물건들",
        icon: Icons.repeat,
        page: "/item_view",
      ),

    ];

    // 2. 전달받은 enabledTiles에 포함된 ID만 필터링해서 반환
    return allTiles.where((tile) => enabledTiles.contains(tile.id)).toList();

  }
}

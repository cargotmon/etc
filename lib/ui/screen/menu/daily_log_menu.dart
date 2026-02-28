import 'package:flutter/material.dart';

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

IconData getMoodIcon(String moodText) {
  if (moodText.contains('피곤') || moodText.contains('늦잠') || moodText.contains('졸림')) {
    return Icons.bedtime; // 밤/잠 아이콘
  } else if (moodText.contains('즐거움') || moodText.contains('행복') || moodText.contains('기쁨')) {
    return Icons.sentiment_very_satisfied; // 아주 기쁜 얼굴
  } else if (moodText.contains('화남') || moodText.contains('짜증')) {
    return Icons.mood_bad; // 좋지 않은 기분
  } else if (moodText.contains('평범') || moodText.contains('보통')) {
    return Icons.sentiment_neutral; // 무표정
  } else {
    return Icons.emoji_emotions; // 기본 기분 아이콘
  }
}
Color getMoodColor(String moodText) {
  if (moodText.contains('피곤') || moodText.contains('늦잠') || moodText.contains('졸림')) {
    return Colors.indigo; // 피곤할 땐 차분한 남색
  } else if (moodText.contains('즐거움') || moodText.contains('행복') || moodText.contains('기쁨')) {
    return Colors.orange; // 즐거울 땐 밝은 주황색
  } else if (moodText.contains('화남') || moodText.contains('짜증')) {
    return Colors.red;    // 화날 땐 빨간색
  } else if (moodText.contains('평범') || moodText.contains('보통')) {
    return Colors.teal;   // 보통일 땐 청록색
  } else {
    return Colors.pink;   // 기본값 분홍색
  }
}

IconData getMedIcon(String timeText) {
  try {
    // "11:22"에서 앞의 "11"만 추출하여 숫자로 변환
    int hour = int.parse(timeText.split(':')[0]);

    if (hour >= 5 && hour < 11) {
      return Icons.wb_twilight; // 아침 (05시~11시)
    } else if (hour >= 11 && hour < 17) {
      return Icons.wb_sunny;    // 점심/오후 (11시~17시)
    } else if (hour >= 17 && hour < 21) {
      return Icons.dark_mode;   // 저녁 (17시~21시)
    } else {
      return Icons.bedtime;     // 밤/심야 (21시~05시)
    }
  } catch (e) {
    // 시간 형식이 아닐 경우 기본 알람 아이콘 표시
    //return Icons.timer
    return Icons.access_alarm;
  }
}

class DailyLogListArea extends StatelessWidget {
  final Function(int) onItemSelected; // 부모에게 인덱스를 전달할 함수
  final bool isTablet;

  const DailyLogListArea({
    super.key,
    required this.onItemSelected,
    required this.isTablet
  });

  // 메뉴 아이템 정의 (나중에 이름도 넣으면 좋겠죠?)
  final List<String> menuNames = const [
    "지출이력", "단어장", "갤러리", "연비", "운동",
    "물건들", "프로젝트 지도", "검색", "설정", "정보"
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: isTablet ? null : AppBar(title: const Text('메뉴')),
      body: ListView.builder(
        itemCount: menuNames.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Icon(_getIconForMenu(index), color: Colors.teal),
            title: Text('${menuNames[index]}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 20),
            onTap: () => onItemSelected(index), // 클릭하면 부모(Dashboard)가 index를 받음
          );
        },
      ),
    );
  }

  // 메뉴별 어울리는 아이콘 매칭
  IconData _getIconForMenu(int index) {
    switch (index) {
      case 0: return Icons.calendar_month;      // 0. 지출 달력
      case 1: return Icons.edit_note;           // 1. 일기장
      case 2: return Icons.photo_library;       // 2. 갤러리
      case 3: return Icons.directions_bike;     // 3. 바이크/여행 기록
      case 4: return Icons.fitness_center;      // 4. 운동 기록
      case 5: return Icons.restaurant;          // 5. 맛집/식단
      case 6: return Icons.map;                 // 6. 동네 한바퀴(지도)
      case 7: return Icons.search;              // 7. 구체적 찾기/기록
      case 8: return Icons.settings;            // 8. 설정
      case 9: return Icons.info_outline;        // 9. 정보/앱 정보
      default: return Icons.circle_outlined;
    }
  }



}

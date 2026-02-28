import 'package:etc/ui/screen/setting.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // DateFormat 사용을 위해 추가 확인
import 'daily_log_menu.dart';
import 'daily_log_detail_view.dart';
import 'package:etc/main.dart';
import 'package:etc/core/gv.dart';
import 'dart:math' as math;

// 💡 [수정] 파일 상단 전역 변수 설정 (앱 시작 시 gv.loadSettings()가 완료된 상태여야 함)
String get gvEmail => gv.email;
String get gvUserId => gv.userId;

// [설정] 서버 주소 정의
const String BASE_URL = 'https://lsj.kr/nexa/';
const String SAVE_URL = '${BASE_URL}nexa_set_daily_log.php';
const String GET_URL  = '${BASE_URL}nexa_get_daily_log.php';
const String LIST_URL = '${BASE_URL}nexa_get_daily_log_all_memos.php';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardView> {
  DateTime currentDay = DateTime.now();
  int? _selectedLogIndex;

  // 💡 [수정] Hive.box 호출을 제거하고 gval 캐시 데이터를 사용합니다.
  // 만약 save_local, save_server 설정도 SQLite에 넣었다면 gval에 변수를 추가해 연결하세요.
  String get userId => gv.userId.trim();
  bool get doSaveLocal => true;  // 기본값 혹은 gval.saveLocal
  bool get doSaveServer => false; // 기본값 혹은 gval.saveServer

  String get todayStr => DateFormat('yyyy-MM-dd').format(currentDay);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 배경색을 전체 테마에 맞게 조정 (필요 시)
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('DLog List'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // IconButton(
          //     icon: const Icon(Icons.history_edu),
          //     onPressed: () => Navigator.push(
          //         context,
          //         MaterialPageRoute(builder: (c) => TimelineScreen(userId: userId, listUrl: LIST_URL))
          //     )
          // ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SettingsScreen())
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isTablet = constraints.maxWidth > 600;

          if (isTablet) {
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DailyLogListArea(
                    isTablet: true,
                    onItemSelected: (index) => setState(() => _selectedLogIndex = index),
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.white10),
                Expanded(
                  flex: 3,
                  child: DailyLogDetailArea(selectedIndex: _selectedLogIndex, isPane: true),
                ),
              ],
            );
          } else {
            return DailyLogListArea(
              isTablet: false,
              onItemSelected: (index) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyLogDetailArea(selectedIndex: index, isPane: false),
                  ),
                ).then((_) => setState(() {})); // 상세화면 갔다 오면 리스트 갱신
              },
            );
          }
        },
      ),
    );
  }
}

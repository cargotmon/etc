import 'package:etc/ui/screen/setting.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etc/ui/screen/menu/dashboard_view.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  DateTime _currentDay = DateTime.now();

  String get todayDisplay =>
      DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_currentDay);

  String get todayQuery =>
      DateFormat('yyyy-MM-dd').format(_currentDay);

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  // DB 조회 자리
  Future<void> _loadDailyData() async {
    debugPrint("📅 load data : $todayQuery");
  }

  // 날짜 변경
  void _changeDay(int offset) {
    setState(() {
      _currentDay = _currentDay.add(Duration(days: offset));
    });

    _loadDailyData();
  }

  // 달력 선택
  Future<void> _selectDate() async {

    final picked = await showDatePicker(
      context: context,
      initialDate: _currentDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _currentDay = picked;
      });

      _loadDailyData();
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      appBar: AppBar(
        // 좌측 햄버거 메뉴
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DashboardView()),
            );
          },
        ),

        title: const Text("감정힐링 일일기록"),

        backgroundColor: Colors.transparent,
        elevation: 0,

        // 우측 버튼들
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),

      body: GestureDetector(

        onHorizontalDragEnd: (details) {

          if (details.primaryVelocity! < 0) {
            _changeDay(1);   // 왼쪽 스와이프 → 다음날
          }

          if (details.primaryVelocity! > 0) {
            _changeDay(-1);  // 오른쪽 스와이프 → 이전날
          }

        },

        child: RefreshIndicator(

          onRefresh: _loadDailyData,

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// 날짜 영역
                GestureDetector(
                  onTap: _selectDate,
                  child: Row(
                    children: [
                      Text(
                        todayDisplay,
                        style: const TextStyle(
                          color: Colors.indigoAccent,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.indigoAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// GRID placeholder
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,

                  children: List.generate(
                    8,
                        (i) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      height: 100,
                      child: Center(
                        child: Text(
                          "Tile ${i + 1}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                /// Memo placeholder
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "오늘 메모 영역",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:etc/server/control/database_helper.dart';

class MoneyMonthPage extends StatefulWidget {
  final String userId;
  const MoneyMonthPage({super.key, required this.userId});

  @override
  State<MoneyMonthPage> createState() => _MoneyMonthPageState();
}

class _MoneyMonthPageState extends State<MoneyMonthPage> {
  DateTime _focusedDay = DateTime.now();
  Map<String, int> _dailyTotals = {}; // 일별 합계
  int _monthlyTotal = 0;              // 월간 총합 (Summary용)
  int _dayCount = 0;                  // 지출이 발생한 일수
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyData(_focusedDay);
  }

  // DB에서 해당 월의 데이터를 불러와 합산
  Future<void> _loadMonthlyData(DateTime month) async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 조회할 월 포맷 (예: 2024-03)
    String yearMonth = DateFormat('yyyy-MM').format(month);

    // 1. 날짜별 합계 쿼리
    final List<Map<String, dynamic>> res = await db.rawQuery('''
      SELECT l.date, SUM(e.price) as day_total
      FROM expenses e
      JOIN daily_logs l ON e.log_uuid = l.uuid
      WHERE l.userid = ? AND l.date LIKE ?
      GROUP BY l.date
    ''', [widget.userId, '$yearMonth%']);

    Map<String, int> tempMap = {};
    int tempMonthlySum = 0;

    for (var row in res) {
      int daySum = (row['day_total'] as num).toInt();
      tempMap[row['date'] as String] = daySum;
      tempMonthlySum += daySum; // 월간 총합 누적
    }

    setState(() {
      _dailyTotals = tempMap;
      _monthlyTotal = tempMonthlySum;
      _dayCount = res.length; // 지출이 기록된 날짜 수
      _isLoading = false;
    });
  }

  // 금액 포맷팅 (3자리 콤마)
  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("월간 지출 리포트", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
        children: [
          TableCalendar(
            locale: 'ko_KR', // 한국어 설정
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            calendarStyle: const CalendarStyle(
              defaultTextStyle: TextStyle(color: Colors.white),
              weekendTextStyle: TextStyle(color: Colors.redAccent),
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
            ),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMonthlyData(focusedDay); // 스와이프 시 재계산
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                String dateStr = DateFormat('yyyy-MM-dd').format(day);
                int? amount = _dailyTotals[dateStr];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${day.day}",
                      style: TextStyle(
                        color: day.weekday == DateTime.sunday ? Colors.redAccent : Colors.white,
                      ),
                    ),
                    if (amount != null && amount > 0)
                      Text(
                        "${(amount / 1000).toStringAsFixed(0)}k",
                        style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ⭐ 실데이터 기반 Summary 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_focusedDay.month}월 지출 총액",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const Icon(Icons.wallet, color: Colors.amber, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${_formatMoney(_monthlyTotal)}원",
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 26,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "이번 달은 총 $_dayCount일 동안 지출이 있었네요.",
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

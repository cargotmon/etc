import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etc/server/control/database_helper.dart';

class MemoMonthPage_ETC extends StatefulWidget {
  final String userId;
  const MemoMonthPage_ETC({super.key, required this.userId});

  @override
  State<MemoMonthPage_ETC> createState() => _MemoMonthPageState();
}

class _MemoMonthPageState extends State<MemoMonthPage_ETC> {
  List<Map<String, dynamic>> _reportList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyReports();
  }

  // 메모, 날씨, 무드, 지출 합계를 한 번에 가져오는 쿼리
  Future<void> _loadDailyReports() async {
    final db = await DatabaseHelper.instance.database;

    // daily_logs를 기준으로 expenses의 합계를 JOIN해서 가져옴
    final res = await db.rawQuery('''
      SELECT l.*, 
             (SELECT SUM(price) FROM expenses WHERE log_uuid = l.uuid) as day_total
      FROM daily_logs l
      WHERE l.userid = ?
      ORDER BY l.date DESC
    ''', [widget.userId]);

    setState(() {
      _reportList = res;
      _isLoading = false;
    });
  }

  // 날씨 아이콘 로직 (기존 WeatherTile과 동일)
  IconData _getWeatherIcon(String? weatherText) {
    final text = weatherText ?? "";
    if (text.contains('비') || text.contains('흐림')) return Icons.umbrella;
    if (text.contains('춥') || text.contains('겨울')) return Icons.ac_unit;
    if (text.contains('맑음')) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  // 감정 아이콘 로직 (기존 MoodBox와 동일)
  IconData _getMoodIcon(String? moodText) {
    final text = moodText ?? "";
    if (text.contains('좋음') || text.contains('행복')) return Icons.sentiment_very_satisfied;
    if (text.contains('슬픔') || text.contains('우울')) return Icons.sentiment_very_dissatisfied;
    if (text.contains('화') || text.contains('분노')) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_satisfied;
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return "0";
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("일일 기록 모아보기", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportList.length,
        itemBuilder: (context, index) {
          final item = _reportList[index];
          final DateTime date = DateTime.parse(item['date']);

          // 월 구분자 로직
          bool showHeader = false;
          if (index == 0) showHeader = true;
          else {
            final prevDate = DateTime.parse(_reportList[index - 1]['date']);
            if (prevDate.month != date.month || prevDate.year != date.year) showHeader = true;
          }

          final int dayTotal = (item['day_total'] ?? 0) as int;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                  child: Text(
                    DateFormat('yyyy년 MM월').format(date),
                    style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),

              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 헤더: 날짜 + 날씨 + 감정
                    Row(
                      children: [
                        Text(
                          DateFormat('dd일 E요일', 'ko_KR').format(date),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        Icon(_getWeatherIcon(item['weather']), color: Colors.orangeAccent, size: 18),
                        const SizedBox(width: 8),
                        Icon(_getMoodIcon(item['mood']), color: Colors.pinkAccent, size: 18),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),

                    // 메모 내용
                    Text(
                      (item['memo'] == null || item['memo'].isEmpty) ? "기록된 생각이 없습니다." : item['memo'],
                      style: TextStyle(
                        color: item['memo'] == null ? Colors.white24 : Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    // 하단 지출 금액
                    if (dayTotal > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments_outlined, color: Colors.amber, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "${_formatMoney(dayTotal)}원 지출",
                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
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

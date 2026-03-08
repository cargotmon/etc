import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
//import 'package:hive/hive.dart';
import 'package:etc/core/gv.dart';

class FuelData {
  final String date;
  final Map<String, double?> prices;
  final Map<String, dynamic> rawValues;

  FuelData(this.date, this.prices, this.rawValues);
}

const String BASE_URL = 'https://lsj.kr/nexa/';

class FuelPriceChartScreen extends StatefulWidget {
  const FuelPriceChartScreen({super.key});

  @override
  State<FuelPriceChartScreen> createState() => _FuelPriceChartScreenState();
}

class _FuelPriceChartScreenState extends State<FuelPriceChartScreen>
{
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      zoomMode: ZoomMode.x,
    );
    super.initState();
  }

  // 데이터 조회 시 user_id(email) 포함
  Future<Map<String, dynamic>> fetchProcessedData() async {
    //final box = Hive.box('settings');
    //final String email = box.get('user_email', defaultValue: "");   //coxycat@naver.com
    final String email = (gv.email == "cargotmon@gmail.com") ? "coxycat@naver.com" : gv.email;


    // [수정] GET 파라미터로 user_id 전달
    final String url = '${BASE_URL}get_fuel_chart_data.php?userid=$email';

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> rawData = decoded['data'] ?? [];

        Set<String> carNames = {};
        List<FuelData> chartList = [];

        for (var row in rawData) {
          final Map<String, dynamic> vals = jsonDecode(row['values_json']);
          Map<String, double?> priceMap = {};

          vals.forEach((key, value) {
            carNames.add(key);
            priceMap[key] = double.tryParse(value.toString());
          });

          chartList.add(FuelData(row['dttm'].toString(), priceMap, vals));
        }

        // 최신순 정렬 (하단 리스트용)
        final List<FuelData> sortedList = List.from(chartList.reversed);

        return {
          'carNames': carNames.toList(),
          'chartData': chartList, // 차트용 (시간순)
          'displayData': sortedList, // 리스트용 (최신순)
        };
      }
    } catch (e) {
      debugPrint("통신 오류: $e");
    }
    return {'carNames': <String>[], 'chartData': <FuelData>[], 'displayData': <FuelData>[]};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1b1e23),
      appBar: AppBar(
        title: const Text("주유단가 통합 비교", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProcessedData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.limeAccent));
          }

          final List<String> carNames = snapshot.data?['carNames'] ?? [];
          final List<FuelData> chartData = snapshot.data?['chartData'] ?? [];
          final List<FuelData> displayData = snapshot.data?['displayData'] ?? [];

          if (chartData.isEmpty) {
            return const Center(child: Text("데이터가 없습니다.", style: TextStyle(color: Colors.white)));
          }

          return Column(
            children: [
              // 1. 차트 영역 (화면 높이의 약 45~50%)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: SfCartesianChart(
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.top,
                    textStyle: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  zoomPanBehavior: _zoomPanBehavior,
                  primaryXAxis: CategoryAxis(
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 9),
                    autoScrollingDelta: 6,
                  ),
                  primaryYAxis: const NumericAxis(
                    minimum: 900, maximum: 2200,
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                  series: carNames.map((name) {
                    return LineSeries<FuelData, String>(
                      name: name,
                      dataSource: chartData,
                      xValueMapper: (FuelData d, _) => d.date,
                      yValueMapper: (FuelData d, _) => d.prices[name],
                      markerSettings: const MarkerSettings(isVisible: true, width: 4, height: 4),
                      emptyPointSettings: EmptyPointSettings(mode: EmptyPointMode.drop),
                    );
                  }).toList(),
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // 2. 실데이터 리스트 영역
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayData.length,
                  separatorBuilder: (v, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = displayData[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.date, style: const TextStyle(color: Colors.limeAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            children: item.rawValues.entries.map((e) {
                              return Text("${e.key}: ${e.value}원",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13));
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

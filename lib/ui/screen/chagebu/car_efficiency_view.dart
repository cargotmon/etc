import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etc/ui/screen/chagebu/chagebu_service.dart'; // 서비스 파일 임포트 확인!
import 'package:etc/ui/screen/chagebu/fuel_price_chart_screen.dart';
import 'package:etc/core/gv.dart';

class CarEfficiencyView extends StatefulWidget {
  const CarEfficiencyView({super.key});

  @override
  State<CarEfficiencyView> createState() => _CarEfficiencyViewState();
}

class _CarEfficiencyViewState extends State<CarEfficiencyView> {
  final ChagebuService _service = ChagebuService();

  bool _isLoading = true;

  // 차량별로 그룹화된 데이터 저장용
  Map<String, List<Map<String, dynamic>>> _groupedData = {};
  List<String> _carList = [];
  String? _selectedCar;

  final _f = NumberFormat('#,###.#');

  @override
  void initState() {
    super.initState();
    _loadEfficiencyData();
  }

  Future<void> _loadEfficiencyData() async {
    setState(() => _isLoading = true);

    //final box = Hive.box('settings');
    //final String email = box.get('user_email', defaultValue: "");
    final String email = (gv.email == "cargotmon@gmail.com") ? "coxycat@naver.com" : gv.email;

    // PHP 호출 (아까 만든 get_car_efficiency.php 연결)
    final data = await _service.fetchCarEfficiency(email);

    // 차량별 그룹핑 로직
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in data) {
      String car = item['car_nm'] ?? 'Unknown';
      grouped.putIfAbsent(car, () => []).add(item);
    }

    // 내가 원하는 순서 리스트
    List<String> preferredOrder = ['MINI', 'CT125', 'Lesley'];

    // 데이터가 있는 차량들 중에서 preferredOrder 순서대로 먼저 필터링
    List<String> sortedCars = preferredOrder.where((car) => grouped.containsKey(car)).toList();

    // 그 외에 리스트에 없지만 데이터가 있는 나머지 차량들 추가
    List<String> otherCars = grouped.keys.where((car) => !preferredOrder.contains(car)).toList();
    sortedCars.addAll(otherCars);

    setState(() {
      _groupedData = grouped;
      //_carList = grouped.keys.toList();
      _carList = sortedCars;
      //if (_carList.isNotEmpty) _selectedCar = _carList[0];
      _selectedCar = _selectedCar ?? (_carList.isNotEmpty ? _carList[0] : null);
      _isLoading = false;
    });
  }

  void _openEditDialog(Map<String, dynamic>? item) {
    // 💡 item이 있으면 수정, 없으면 추가!
    final bool isEdit = item != null;

    // 기본값 세팅 (수정일 경우 기존값, 추가일 경우 빈값)
    TextEditingController div2 = TextEditingController(text: item?['div2']?.toString() ?? '');
    TextEditingController kmController = TextEditingController(text: item?['total_km']?.toString() ?? '');
    TextEditingController priceController = TextEditingController(text: item?['price']?.toString() ?? '');
    TextEditingController unitController = TextEditingController(text: item?['unit_price']?.toString() ?? '');

    TextEditingController locController = TextEditingController(text: item?['loc']?.toString() ?? '');
    TextEditingController remkController = TextEditingController(text: item?['remk']?.toString() ?? '');

    String selectedCar = item?['car_nm'] ?? _selectedCar ?? 'MINI';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? "연비 기록 수정" : "새 주유 기록 추가"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              // 차량 선택 (수정 시에는 변경 못하게 하거나 Dropdown으로)
              DropdownButton<String>(
                value: selectedCar,
                items: _carList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: isEdit ? null : (val) => setState(() => selectedCar = val!),
              ),
              TextField(controller: div2, decoration: const InputDecoration(labelText: "구분"), keyboardType: TextInputType.text),
              TextField(controller: kmController, decoration: const InputDecoration(labelText: "현재 적산거리 (km)"), keyboardType: TextInputType.number),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: "주유 금액 (원)"), keyboardType: TextInputType.number),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: "리터당 단가 (원)"), keyboardType: TextInputType.number),
              TextField(controller: locController, decoration: const InputDecoration(labelText: "장소"), keyboardType: TextInputType.text),
              TextField(controller: remkController, decoration: const InputDecoration(labelText: "비고"), keyboardType: TextInputType.text),
            ],
          ),
        ),
        actions: [
            if (item != null) // 수정 모드일 때만 삭제 버튼 노출
            TextButton(
              onPressed: () => _confirmDelete(item),
              child: const Text("삭제", style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. 필수값 체크
              if (kmController.text.isEmpty || priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("주행거리와 금액은 필수입니다!"))
                );
                return;
              }

              //final box = Hive.box('settings');
              //final String _userEmail = box.get('user_email', defaultValue: "");
              final String _userEmail = (gv.email == "cargotmon@gmail.com") ? "coxycat@naver.com" : gv.email;

              print(">>>loc: " + locController.text);
              // 2. 데이터 준비
              final Map<String, dynamic> saveData = {
                "userid": _userEmail,
                "car_nm": selectedCar,
                "dttm": item?['dttm'] ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                "km": double.tryParse(kmController.text) ?? 0,
                "price": int.tryParse(priceController.text) ?? 0,
                "unit_price": int.tryParse(unitController.text) ?? 0,
                "loc": locController.text,
                "remk": remkController.text,
                "div2": div2.text,
              };

              // 3. 서비스 호출
              final bool success = await _service.saveChagebu(saveData);

              if (success) {
                if (!context.mounted) return;
                Navigator.pop(context); // 팝업 닫기

                _loadEfficiencyData(); // 새로고침
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("차계부가 저장되었습니다! ⛽"))
                );
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("저장 실패... 서버를 확인해주세요."))
                );
              }
            }, // 👈 onPressed 종료
            child: const Text("저장"), // 👈 child는 함수 밖에 있어야 함!
          ),
        ],
      ),
    );
  }
  // 삭제 확인 팝업 함수
  void _confirmDelete22(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("데이터 삭제"),
        content: const Text("이 주유 기록을 삭제할까요?\n연비 계산에 영향을 줄 수 있습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          TextButton(
            onPressed: () async {

              //final box = Hive.box('settings');
              //final String _userEmail = box.get('user_email', defaultValue: "");
              final String _userEmail = (gv.email == "cargotmon@gmail.com") ? "coxycat@naver.com" : gv.email;

              // 💡 2. 서비스 호출 (delete_chagebu.php)
              final bool success = await _service.deleteChagebu({
                "userid": _userEmail,
                "car_nm": item['car_nm'],
                "dttm": item['dttm'],
              });
              if (success) {
                Navigator.pop(context); // 확인창 닫기
                Navigator.pop(context); // 수정창 닫기
                _loadEfficiencyData(); // 목록 새로고침
              }
            },
            child: const Text("지우기", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( // 다이얼로그용 컨텍스트 구분
        title: const Text("데이터 삭제"),
        content: const Text("이 주유 기록을 삭제할까요?\n연비 계산에 영향을 줄 수 있습니다."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("취소")
          ),
          TextButton(
            onPressed: () async {
              // 1. 세팅값 로드
              //final box = Hive.box('settings');
              //final String userEmail = box.get('user_email', defaultValue: "");
              final String userEmail = (gv.email == "cargotmon@gmail.com") ? "coxycat@naver.com" : gv.email;

              try {
                // 2. 서비스 호출 (성공/실패 여부를 기다림)
                final bool success = await _service.deleteChagebu({
                  "userid": userEmail,
                  "car_nm": item['car_nm'],
                  "dttm": item['dttm'],
                }).timeout(const Duration(seconds: 5)); // 5초 타임아웃 추가

                if (success) {
                  // 3. 빌드 컨텍스트가 여전히 유효한지 체크 (플러터 권장사항)
                  if (!mounted) return;

                  // 💡 다이얼로그 2개를 순차적으로 닫고 데이터 갱신
                  Navigator.of(dialogContext).pop(); // 1. 확인 팝업 닫기
                  Navigator.of(context).pop();      // 2. 수정 팝업 닫기

                  _loadEfficiencyData(); // 🚀 목록 새로고침

                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("기록이 삭제되었습니다."))
                  );
                } else {
                  throw Exception("서버 응답 실패");
                }
              } catch (e) {
                // 에러 발생 시 로그 찍고 사용자에게 알림
                print("❌ 삭제 에러: $e");
                if (!mounted) return;
                Navigator.of(dialogContext).pop(); // 에러 나더라도 확인창은 닫아줌
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("삭제 실패: $e"))
                );
              }
            },
            child: const Text("지우기", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_carList.isEmpty) return const Center(child: Text("주유 기록이 없어요 ⛽"));

    final currentData = _groupedData[_selectedCar] ?? [];

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('연비 대시보드'),
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildCarSelector(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add_road, color: Colors.white),
        onPressed: () => _openEditDialog(null), // null을 넘기면 '추가' 모드
      ),
      body: Column(
        children: [
          _buildSummaryHeader(currentData),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: currentData.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  // 💡 2. 카드 클릭 시 수정 팝업 호출
                  onTap: () => _openEditDialog(currentData[index]),
                  child: _buildEfficiencyCard(currentData[index]),
                );
              },
            ),
          ),
        ]
      ),
    );
  }

  // 차량 선택 탭 (Horizontal Chips)
  Widget _buildCarSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _carList.map((car) {
          bool isSelected = _selectedCar == car;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(car),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCar = car),
              selectedColor: Colors.teal,
              backgroundColor: Colors.grey[900],
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 개별 연비 기록 카드
  Widget _buildEfficiencyCard(Map<String, dynamic> item) {
    double eff = double.tryParse(item['fuel_efficiency']?.toString() ?? '0') ?? 0;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item['dttm'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text("${_f.format(eff)} km/l",
                style: TextStyle(color: eff > 15 ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text("📍 ${item['loc'] ?? '장소 미기입'}", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Row(
              children: [ // "${_f.format(eff)} km/L"
                _infoBadge("km: ${_f.format(num.tryParse(item['total_km'].toString()) ?? 0)}km"),
                const SizedBox(width: 8),
                _infoBadge("주유: ${item['liters']}L"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    );
  }

  Widget _buildSummaryHeader(List<Map<String, dynamic>> currentData) {
    if (currentData.isEmpty) return const SizedBox.shrink();

    // 💡 최신 데이터(0번 인덱스)가 마지막 적산 거리입니다.
    final latestRecord = currentData[0];
    final String lastKm = _f.format(double.tryParse(latestRecord['total_km'].toString()) ?? 0);
    final String sLastOilKm = _f.format(double.tryParse(latestRecord['last_oil_km'].toString()) ?? 0);

    // 평균 연비 계산
    double totalEff = 0;
    double tripKm = 0;
    double avgUnit = 0;
    int count = 0;
    for (var item in currentData) {
      double? eff = double.tryParse(item['fuel_efficiency']?.toString() ?? '');
      double? trip = double.tryParse(item['trip_km']?.toString() ?? '');
      double? unit_price = double.tryParse(item['unit_price']?.toString() ?? '');

      if (eff != null) {
        totalEff += eff;
        count++;
      }
      if(trip != null) {
        tripKm += trip;
      }
      if(unit_price != null) {
        avgUnit += unit_price;
      }
    }
    String avgEff = count > 0 ? _f.format(totalEff / count) : "0.0";
    String trip_km = count > 0 ? _f.format(tripKm / count) : "0.0";
    String sAvgUnit = count > 0 ? _f.format(avgUnit / count) : "0.0";

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade400]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FuelPriceChartScreen()),
                  );
                },
                child: const Text("그래프", style: TextStyle(color: Colors.greenAccent
                    , fontSize: 14) ),    //, fontWeight: FontWeight.normal
              ),
              const Text("마지막 적산거리", style: TextStyle(color: Colors.black54, fontSize: 18)),
              const Text("ㅋ", style: TextStyle(color: Colors.black54, fontSize: 14)),
              const SizedBox(width: 4),
              Text("$_selectedCar", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text("$lastKm km",
              style: TextStyle(color: Colors.white
                  , fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          // 💡 [핵심] 큼직하게 보여주는 마지막 적산 거리
          Text("오일교환: $sLastOilKm km",
              style: TextStyle(color: Colors.yellow, fontSize: 14,
                  fontWeight: FontWeight.w900, letterSpacing: 1.2
              )),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem("평균 연비", "$avgEff ㎞/ℓ"),
              _summaryItem("평균 trip", "$trip_km"),
              _summaryItem("평균 단가", "${sAvgUnit}원"),
              _summaryItem("기록 횟수", "${currentData.length}회"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

}

import 'package:etc/ui/screen/box/memo_box.dart';
import 'package:etc/ui/screen/box/todo_box.dart';
import 'package:etc/ui/screen/dashboard_box.dart'; // DashboardTileFactory가 있는 곳
import 'package:etc/ui/screen/setting.dart'; // SettingsScreen 경로 확인 필요
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etc/ui/screen/menu/dashboard_view.dart';
import 'package:etc/core/gv.dart';
// ⭐ 추가된 import (설정 관리자)
import 'package:etc/ui/screen/setting/tile_settings_manager.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DateTime _currentDay = DateTime.now();
  List<DashboardTile> tiles = [];
  bool _isTileLoading = true; // 타일 로딩 상태 추가

  String get todayDisplay => DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_currentDay);
  String get todayQuery => DateFormat('yyyy-MM-dd').format(_currentDay);

  String get _displayName {
    if (gv.email == "없음" || !gv.email.contains('@')) return "사용자";
    return gv.email.split('@')[0];
  }

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  // ⭐ 데이터 및 설정값 로드 로직 수정
  Future<void> _loadDailyData33() async {
    debugPrint("📅 load data : $todayQuery");
    if (!mounted) return;

    setState(() => _isTileLoading = true);

    try {
      // 1. 저장된 활성화 타일 ID 리스트 가져오기
      final List<String> enabledIds = await TileSettingsManager.getEnabledTiles();

      // 2. 팩토리를 통해 모든 타일 생성 (파라미터 이름 명시 호출)
      // final allTiles = DashboardTileFactory.buildTiles(
      //   context: context,    // 이름 붙은 파라미터로 수정
      //   userId: gv.userId,
      //   date: todayQuery,
      // );
      // 2. 팩토리를 통해 모든 타일 생성 (파라미터 이름 명시 호출)
      final allTiles = DashboardTileFactory.buildTiles(
        context: context,
        userId: gv.userId,
        date: todayQuery,
        enabledTiles: enabledIds, customNames: {}, // 👈 이 줄이 빠져서 오류가 났던 것입니다!
      );

      // 3. 설정값에 포함된 ID만 필터링하여 상태 업데이트
      if (mounted) {
        setState(() {
          tiles = allTiles.where((t) => enabledIds.contains(t.id)).toList();
          _isTileLoading = false;
        });
      }

      debugPrint("✅ [Dashboard] 타일 필터링 완료: ${tiles.length}개");
    } catch (e) {
      debugPrint("❌ [Dashboard] 데이터 로드 실패: $e");
      if (mounted) setState(() => _isTileLoading = false);
    }
  }

  Future<void> _loadDailyData() async {
    setState(() => _isTileLoading = true);

    try {
      // 1. 설정값들(순서/ID, 커스텀 명칭) 병렬로 가져오기
      final List<String> enabledIds = await TileSettingsManager.getEnabledTiles();
      final Map<String, String> customNames = await TileSettingsManager.getCustomNames();

      // 2. 팩토리에 모든 데이터 전달
      final resultTiles = DashboardTileFactory.buildTiles(
        context: context,
        userId: gv.userId,
        date: todayQuery,
        enabledTiles: enabledIds, // 순서 반영용
        customNames: customNames, // 명칭 반영용
      );

      setState(() {
        tiles = resultTiles;
        _isTileLoading = false;
      });
    } catch (e) {
      debugPrint("❌ 데이터 로드 실패: $e");
      setState(() => _isTileLoading = false);
    }
  }

  void _changeDay(int offset) {
    setState(() {
      _currentDay = _currentDay.add(Duration(days: offset));
    });
    _loadDailyData();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _currentDay = picked);
      _loadDailyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardView())),
        ),
        title: const Text("Emotion Trash Can"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // ⭐ 설정 화면 이동 후 돌아왔을 때 타일 구성 새로고침
              await Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen()));
              _loadDailyData();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) _changeDay(1);
          if (details.primaryVelocity! > 0) _changeDay(-1);
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
                      Text(todayDisplay, style: const TextStyle(color: Colors.indigoAccent, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, color: Colors.indigoAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('$_displayName님, 안녕하세요!', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, height: 1.2)),
                const SizedBox(height: 10),

                // ⭐ 타일 영역 (로딩 처리 포함)
                _isTileLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    : GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: tiles.map((tile) {
                    // 커스텀 위젯(WeatherTile 등)이 있으면 그것을 반환
                    if (tile.child != null) return tile.child!;

                    // 일반 타일 처리
                    return GestureDetector(
                      onTap: () {
                        if (tile.onTap != null) {
                          tile.onTap!();
                        } else if (tile.page is String) {
                          Navigator.pushNamed(context, tile.page);
                        } else if (tile.page is Widget) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => tile.page));
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tile.icon, color: Colors.white, size: 28),
                            const SizedBox(height: 6),
                            Text(tile.title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                TodoBox(userId: gv.userId, date: todayQuery),
                const SizedBox(height: 20),
                MemoBox(userId: gv.userId, date: todayQuery),
                const SizedBox(height: 150),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

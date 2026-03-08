import 'package:flutter/material.dart';
import 'tile_settings_manager.dart';

class TileConfigScreen extends StatefulWidget {
  const TileConfigScreen({super.key});

  @override
  State<TileConfigScreen> createState() => _TileConfigScreenState();
}

class _TileConfigScreenState extends State<TileConfigScreen> {
  List<String> _enabledTiles = [];
  Map<String, String> _customNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 설정 및 이름 데이터 로드
  Future<void> _loadSettings() async {
    final tiles = await TileSettingsManager.getEnabledTiles();
    final names = await TileSettingsManager.getCustomNames();
    setState(() {
      _enabledTiles = tiles;
      _customNames = names;
      _isLoading = false;
    });
  }

  // 드래그 순서 변경
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final String item = _enabledTiles.removeAt(oldIndex);
      _enabledTiles.insert(newIndex, item);
    });
    TileSettingsManager.saveEnabledTiles(_enabledTiles);
  }

  // 활성화 토글
  void _toggleTile(String id, bool? value) {
    setState(() {
      if (value == true) {
        if (!_enabledTiles.contains(id)) _enabledTiles.add(id);
      } else {
        _enabledTiles.remove(id);
      }
    });
    TileSettingsManager.saveEnabledTiles(_enabledTiles);
  }

  // 이름 수정 다이얼로그
  void _showRenameDialog(String id) {
    TextEditingController c = TextEditingController(text: _getDisplayName(id));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("타일 이름 수정", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "새 이름을 입력하세요",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(
            onPressed: () async {
              if (c.text.trim().isNotEmpty) {
                await TileSettingsManager.saveCustomName(id, c.text.trim());
                _loadSettings(); // 화면 갱신
              }
              Navigator.pop(ctx);
            },
            child: const Text("저장"),
          ),
        ],
      ),
    );
  }

  // 저장된 이름이 있으면 반환, 없으면 기본값 반환
  String _getDisplayName(String id) {
    if (_customNames.containsKey(id)) return _customNames[id]!;

    switch (id) {
      case "weather": return "오늘의 날씨";
      case "emotion": return "감정 상태";
      case "med1": return "아침 약";
      case "med2": return "점심 약";
      case "med3": return "저녁 약";
      case "chagebu": return "차계부";
      case "money": return "지출 관리";
      //case "memo": return "오늘의 메모";
      case "habit": return "물건 관리";
      default: return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("대시보드 설정", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () async {
              await TileSettingsManager.saveEnabledTiles(TileSettingsManager.allTileIds);
              _loadSettings();
            },
            child: const Text("초기화", style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("길게 눌러 순서 변경 / 우측 체크로 숨기기 가능\n이름 옆 연필 아이콘으로 텍스트 수정 가능",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: _onReorder,
              children: _enabledTiles.map((id) {
                return ListTile(
                  key: ValueKey(id),
                  leading: const Icon(Icons.drag_handle, color: Colors.white24),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(_getDisplayName(id), style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Colors.pinkAccent),
                        onPressed: () => _showRenameDialog(id),
                      ),
                    ],
                  ),
                  subtitle: Text(id, style: const TextStyle(color: Colors.white10, fontSize: 10)),
                  trailing: Checkbox(
                    activeColor: Colors.pinkAccent,
                    value: _enabledTiles.contains(id),
                    onChanged: (val) => _toggleTile(id, val),
                  ),
                );
              }).toList(),
            ),
          ),
          Text("길게 눌러 순서 변경 / 우측 체크로 숨기기 가능\n이름 옆 연필 아이콘으로 텍스트 수정 가능",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

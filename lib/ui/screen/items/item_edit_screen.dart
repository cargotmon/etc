import 'package:flutter/material.dart';
import 'package:etc/server/model/item_model.dart';
import 'package:etc/server/model/loc_model.dart';
import 'package:etc/server/control/database_helper.dart';

class ItemEditScreen extends StatefulWidget {
  final ItemModel item;

  const ItemEditScreen({super.key, required this.item});

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _memoController;
  late TextEditingController _eaController;
  final TextEditingController _locController = TextEditingController();

  List<LocModel> _locList = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _memoController = TextEditingController(text: widget.item.memo);
    _eaController = TextEditingController(text: widget.item.ea.toString());
    _locController.text = "로딩 중...";
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final data = await DatabaseHelper.instance.getLocations();
    String currentLocName = "";
    if (widget.item.locSn != null) {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query('loc', columns: ['loc1'], where: 'sn = ?', whereArgs: [widget.item.locSn]);
      if (res.isNotEmpty) currentLocName = res.first['loc1'].toString();
    }

    if (mounted) {
      setState(() {
        _locList = data.map((e) => LocModel.fromMap(e)).toList();
        _locController.text = currentLocName.isEmpty ? "" : currentLocName;
      });
    }
  }

  Future<void> _updateItem() async {
    if (_nameController.text.isEmpty) return;
    final updatedData = widget.item.toMap();
    updatedData['name'] = _nameController.text.trim();
    updatedData['memo'] = _memoController.text.trim();
    updatedData['ea'] = int.tryParse(_eaController.text) ?? 1;
    updatedData['sync_yn'] = 'N';

    await DatabaseHelper.instance.saveItemWithLocName(
      itemData: updatedData,
      locName: _locController.text.trim().isEmpty ? "미지정" : _locController.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // 다크 테마 배경색 설정
    const bgColor = Color(0xFF121212);
    const surfaceColor = Color(0xFF1E1E1E);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgColor,
        colorScheme: const ColorScheme.dark(primary: Colors.tealAccent),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('물건 정보 수정', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: surfaceColor,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () {}), // 삭제 로직 생략
            IconButton(icon: const Icon(Icons.check, color: Colors.tealAccent), onPressed: _updateItem),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildDarkTextField(_nameController, '물건 이름', Icons.inventory_2),
              const SizedBox(height: 20),

              // 💡 다크모드 Autocomplete
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _locList.map((e) => e.loc1);
                  return _locList.map((e) => e.loc1).where((name) => name.contains(textEditingValue.text));
                },
                onSelected: (String selection) => _locController.text = selection,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (controller.text.isEmpty && _locController.text.isNotEmpty && _locController.text != "로딩 중...") {
                    controller.text = _locController.text;
                  }
                  return _buildDarkTextField(controller, '보관 장소', Icons.location_on, focusNode: focusNode,
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.text.isNotEmpty)
                          IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { controller.clear(); _locController.clear(); }),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                    onChanged: (val) => _locController.text = val,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: surfaceColor, // 💡 리스트 배경도 어둡게
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 32,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option, style: const TextStyle(color: Colors.white70)),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              _buildDarkTextField(_eaController, '수량', Icons.add_circle_outline, isNumber: true),
              const SizedBox(height: 20),
              _buildDarkTextField(_memoController, '메모', Icons.notes, maxLines: 5),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _updateItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('수정 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 💡 블랙 테마 전용 텍스트 필드 빌더
  Widget _buildDarkTextField(TextEditingController controller, String label, IconData icon,
      {bool isNumber = false, int maxLines = 1, FocusNode? focusNode, Widget? suffix, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.tealAccent),
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.tealAccent)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose(); _memoController.dispose(); _eaController.dispose(); _locController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:etc/server/model/loc_model.dart';
import 'package:etc/server/control/database_helper.dart';

class ItemAddScreen extends StatefulWidget {
  const ItemAddScreen({super.key});

  @override
  State<ItemAddScreen> createState() => _ItemAddScreenState();
}

class _ItemAddScreenState extends State<ItemAddScreen> {
  final _nameController = TextEditingController();
  final _memoController = TextEditingController();
  final _locController = TextEditingController();

  List<LocModel> _locList = [];

  @override
  void initState() {
    super.initState();
    _loadLocList();
  }

  Future<void> _loadLocList() async {
    final data = await DatabaseHelper.instance.getLocations();
    if (mounted) {
      setState(() {
        _locList = data.map((e) => LocModel.fromMap(e)).toList();
      });
    }
  }

  Future<void> _saveItem() async {
    final name = _nameController.text.trim();
    final locName = _locController.text.trim();
    if (name.isEmpty || locName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이름과 장소는 필수입니다!')));
      return;
    }

    final itemData = {
      'name': name,
      'memo': _memoController.text.trim(),
      'category': '일반',
      'owner_email': 'coxycat@naver.com',
      'holder_email': 'coxycat@naver.com',
      'ea': 1,
      'sync_yn': 'N',
    };

    await DatabaseHelper.instance.saveItemWithLocName(itemData: itemData, locName: locName);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 물건 등록'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '물건 이름 *', prefixIcon: Icon(Icons.inventory))),
            const SizedBox(height: 15),
            RawAutocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                return _locList.map((e) => e.loc1).where((name) => name.contains(textEditingValue.text));
              },
              onSelected: (String selection) { _locController.text = selection; },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (val) => _locController.text = val,
                  decoration: const InputDecoration(labelText: '보관 장소 (선택 또는 직접 입력) *', prefixIcon: Icon(Icons.location_on), suffixIcon: Icon(Icons.arrow_drop_down)),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(title: Text(option), onTap: () => onSelected(option));
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            TextField(controller: _memoController, decoration: const InputDecoration(labelText: '메모', alignLabelWithHint: true), maxLines: 5),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveItem,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(55)),
              child: const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

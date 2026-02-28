import 'package:flutter/material.dart';
import 'package:etc/ui/screen/verbs/verb_service.dart';

class VerbStudyView extends StatefulWidget {
  const VerbStudyView({super.key});

  @override
  State<VerbStudyView> createState() => _VerbStudyViewState();
}

class _VerbStudyViewState extends State<VerbStudyView> {
  final VerbService _service = VerbService();
  List<Map<String, dynamic>> _verbs = [];
  bool _isLoading = true;
  bool _showMeaning = false; // 뜻을 가렸다가 보여주는 용도

  @override
  void initState() {
    super.initState();
    _loadVerbs();
  }

  Future<void> _loadVerbs() async {
    setState(() => _isLoading = true);
    // 아까 만든 PHP 호출 (랜덤 20개)
    final data = await _service.fetchVerbQuizzes(limit: 20);
    setState(() {
      _verbs = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_verbs.isEmpty) return const Center(child: Text("데이터가 없어요 ㅠ"));

    return Scaffold(
      backgroundColor: Colors.black87,
      body: PageView.builder(
        itemCount: _verbs.length,
        onPageChanged: (_) => setState(() => _showMeaning = false), // 페이지 넘기면 다시 가리기
        itemBuilder: (context, index) {
          final item = _verbs[index];
          return _buildVerbCard(item);
        },
      ),
    );
  }

  Widget _buildVerbCard(Map<String, dynamic> item) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _showMeaning = !_showMeaning), // 터치하면 뜻 공개
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: 450,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: _showMeaning ? Colors.teal.shade900 : Colors.grey.shade900,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 15)],
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Base Form", style: TextStyle(color: Colors.tealAccent, fontSize: 14)),
              const SizedBox(height: 10),
              Text(item['base_form'],
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(item['pronunciation'], style: const TextStyle(color: Colors.grey, fontSize: 18)),

              const Divider(height: 60, color: Colors.white24),

              if (!_showMeaning)
                const Text("터치해서 뜻 확인하기", style: TextStyle(color: Colors.white38))
              else
                Column(
                  children: [
                    Text(item['meaning'],
                        style: const TextStyle(fontSize: 22, color: Colors.yellowAccent, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Text(item['example_sentence'],
                        style: const TextStyle(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}


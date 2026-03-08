import 'package:flutter/material.dart';
import 'package:etc/server/control/database_helper.dart';
import 'package:uuid/uuid.dart';

class TodoBox extends StatefulWidget {
  final String userId;
  final String date;

  const TodoBox({super.key, required this.userId, required this.date});

  @override
  State<TodoBox> createState() => _TodoBoxState();
}

class _TodoBoxState extends State<TodoBox> {
  List<Map<String, dynamic>> _todoList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void didUpdateWidget(covariant TodoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.userId != widget.userId) {
      setState(() => isLoading = true);
      _loadTodos();
    }
  }

  // 1. 목록 불러오기
  Future<void> _loadTodos() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query(
        "todos",
        where: "userid=? AND date=?",
        whereArgs: [widget.userId, widget.date],
        orderBy: "is_done ASC, sn DESC",
      );
      setState(() {
        _todoList = res;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ [TodoBox] 로드 에러: $e");
      setState(() => isLoading = false);
    }
  }

  String _getNowTime() =>
      "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

  // 2. 할 일 추가
  Future<void> _addTodo(String content) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert("todos", {
      "uuid": const Uuid().v4(),
      "userid": widget.userId,
      "date": widget.date,
      "content": content,
      "start_time": _getNowTime(),
      "is_done": 0,
    });
    _loadTodos();
  }

  // 3. 완료 상태 토글 (완료 시 end_time 기록)
  Future<void> _toggleDone(Map<String, dynamic> item) async {
    final db = await DatabaseHelper.instance.database;
    final bool isCurrentlyDone = item['is_done'] == 1;
    await db.update(
      "todos",
      {
        "is_done": isCurrentlyDone ? 0 : 1,
        "end_time": isCurrentlyDone ? null : _getNowTime(),
      },
      where: "sn=?",
      whereArgs: [item['sn']],
    );
    _loadTodos();
  }

  // 4. 삭제
  Future<void> _deleteTodo(int sn) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete("todos", where: "sn=?", whereArgs: [sn]);
    _loadTodos();
  }

  void _showAddDialog() {
    TextEditingController c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("📝 새 할 일 추가"),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: "무엇을 해야 하나요?"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소")),
          ElevatedButton(
            onPressed: () {
              if (c.text.isNotEmpty) _addTodo(c.text);
              Navigator.pop(ctx);
            },
            child: const Text("추가"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // ⭐ 오타 수정됨
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text("오늘의 할 일",
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, color: Colors.greenAccent, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_todoList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("할 일이 없어요. +를 눌러 추가해보세요!",
                  style: TextStyle(color: Colors.white24, fontSize: 13))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todoList.length,
              itemBuilder: (context, index) {
                final item = _todoList[index];
                final bool isDone = item['is_done'] == 1;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(vertical: -4),
                  leading: IconButton(
                    icon: Icon(
                      isDone ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isDone ? Colors.greenAccent : Colors.white30,
                    ),
                    onPressed: () => _toggleDone(item),
                  ),
                  title: Text(
                    item['content'],
                    style: TextStyle(
                      color: isDone ? Colors.white30 : Colors.white,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    "시작: ${item['start_time'] ?? '-'} ${isDone ? '| 완료: ${item['end_time'] ?? '-'}' : ''}",
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white24, size: 16),
                    onPressed: () => _deleteTodo(item['sn']),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

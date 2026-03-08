import 'package:etc/ui/screen/money/money_month.dart';
import 'package:flutter/material.dart';
import 'package:etc/server/control/database_helper.dart';
import 'package:uuid/uuid.dart';

class MoneyBox extends StatefulWidget {
  final String userId;
  final String date;

  const MoneyBox({super.key, required this.userId, required this.date});

  @override
  State<MoneyBox> createState() => _MoneyBoxState();
}

class _MoneyBoxState extends State<MoneyBox> {
  int totalAmount = 0;
  List<Map<String, dynamic>> _expenseList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void didUpdateWidget(covariant MoneyBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.userId != widget.userId) {
      setState(() => isLoading = true);
      _loadExpenses();
    }
  }

  // 1. 지출 내역 및 합계 불러오기
  Future<void> _loadExpenses() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final List<Map<String, dynamic>> res = await db.rawQuery('''
        SELECT e.* FROM expenses e
        JOIN daily_logs l ON e.log_uuid = l.uuid
        WHERE l.userid = ? AND l.date = ?
      ''', [widget.userId, widget.date]);

      int sum = 0;
      for (var item in res) {
        sum += (item['price'] as int? ?? 0);
      }

      setState(() {
        _expenseList = res;
        totalAmount = sum;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ [MoneyBox] 로드 에러: $e");
      setState(() => isLoading = false);
    }
  }

  // 2. 지출 추가
  Future<void> _addExpense(String item, int price) async {
    try {
      final db = await DatabaseHelper.instance.database;
      var log = await db.query("daily_logs", where: "userid=? AND date=?", whereArgs: [widget.userId, widget.date]);
      String logUuid;

      if (log.isEmpty) {
        logUuid = const Uuid().v4();
        await db.insert("daily_logs", {
          "uuid": logUuid,
          "userid": widget.userId,
          "date": widget.date,
        });
      } else {
        logUuid = log.first['uuid'] as String;
      }

      await db.insert("expenses", {
        "log_uuid": logUuid,
        "item": item,
        "price": price,
      });

      _loadExpenses();
    } catch (e) {
      debugPrint("❌ [MoneyBox] 추가 에러: $e");
    }
  }

  // 3. 지출 삭제
  Future<void> _deleteExpense(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete("expenses", where: "id = ?", whereArgs: [id]);
    _loadExpenses();
  }

  // 천단위 콤마 포맷 함수
  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  // 4. 지출 입력 팝업
  void _showExpenseDialog() {
    final itemController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          //title: const Text("💸 지출 내역 관리"),
          title: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MoneyMonthPage(userId: widget.userId)),
              );
            },
            child: const Text("💸 지출 내역 관리 >"), // '>'를 붙여주면 클릭 가능하다는 느낌을 줍니다.
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: _expenseList.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("기록이 없습니다.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _expenseList.length,
                    itemBuilder: (context, index) {
                      final e = _expenseList[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: const VisualDensity(vertical: -4),
                        title: Text("${e['item']}", style: const TextStyle(fontSize: 13)),
                        trailing: Text("${_formatMoney(e['price'] as int)}원", style: const TextStyle(fontSize: 13)),
                        leading: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          onPressed: () async {
                            await _deleteExpense(e['id']);
                            setModalState(() {}); // 다이얼로그 내부 UI 갱신
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                TextField(
                    controller: itemController,
                    decoration: const InputDecoration(hintText: "항목 (예: 점심)", isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: priceController,
                    decoration: const InputDecoration(hintText: "금액", isDense: true),
                    keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("닫기")),
            ElevatedButton(
              onPressed: () async {
                if (itemController.text.isNotEmpty && priceController.text.isNotEmpty) {
                  await _addExpense(itemController.text, int.parse(priceController.text));
                  if (mounted) Navigator.pop(ctx);
                }
              },
              child: const Text("추가"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ 지출 유무에 따른 색상 로직 적용 (Amber 계열 사용)
    final bool hasValue = totalAmount > 0;
    final Color activeColor = hasValue ? Colors.amber : Colors.grey;

    return GestureDetector(
      onTap: _showExpenseDialog,
      child: Container(
        decoration: BoxDecoration(
          color: activeColor.withOpacity(hasValue ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasValue ? activeColor.withOpacity(0.5) : Colors.white10,
          ),
        ),
        child: isLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                Icons.payments_outlined,
                color: activeColor,
                size: 28
            ),
            const SizedBox(height: 6),
            Text(
                "지출",
                style: TextStyle(
                    color: hasValue ? Colors.white70 : Colors.white38,
                    fontSize: 10
                )
            ),
            const SizedBox(height: 2),
            Text(
              hasValue ? "${_formatMoney(totalAmount)}원" : "0원",
              style: TextStyle(
                  color: hasValue ? activeColor : Colors.white24,
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }
}

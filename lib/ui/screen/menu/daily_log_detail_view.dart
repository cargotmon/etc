import 'package:etc/ui/screen/chagebu/car_efficiency_view.dart';
import 'package:etc/ui/screen/items/item_list_screen.dart';
import 'package:etc/ui/screen/verbs/verb_study_view.dart';
import 'package:flutter/material.dart';
//import 'package:dlog/money/money_dal_view.dart';
//import '../ui/screens/verbs/verb_study_view.dart';
//import 'package:dlog/ui/screens/chagebu/car_efficiency_view.dart';
//import 'package:dlog/ui/screens/items/item_list_screen.dart';

class DailyLogDetailArea extends StatelessWidget {
  final int? selectedIndex;
  final bool isPane;

  const DailyLogDetailArea({
    super.key,
    this.selectedIndex,
    this.isPane = true
  });

  // 1. 클래스 내부 위젯 결정 함수
  Widget _getMenuWidget(int index) {
    switch (index) {
      //case 0: return const MoneyDalView();
      case 1: return const VerbStudyView();
      case 2: return const Center(child: Text("갤러리 준비 중..."));
      case 3: return const CarEfficiencyView();
      case 5: return const ItemListScreen();
      default: return Center(child: Text("$index번 상세 내용... 🚧"));
    }
  }

  // 2. 클래스 내부 타이틀 결정 함수
  String _getMenuTitle(int index) {
    switch (index) {
      case 0: return "지출 달력";
      case 1: return "동사 마스터";
      case 2: return "갤러리";
      case 3: return "연비";
      default: return "상세 내용";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 💡 [중요] null 체크를 가장 먼저 해서 터지는 걸 원천 차단!
    if (selectedIndex == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text("왼쪽 메뉴에서 로그를 선택해주세요.", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // 💡 null이 아님이 확실할 때 로컬 변수에 담아 사용 (안전 바이브)
    final int index = selectedIndex!;
    final String sTitle = _getMenuTitle(index);
    final Widget content = _getMenuWidget(index);

    return Scaffold(
      appBar: isPane
          ? null
          : AppBar(
        title: Text('$index. $sTitle'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () {
              print("맨 앞으로!");
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: content,
    );
  }
}

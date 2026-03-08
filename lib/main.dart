import 'package:etc/ui/screen/all_memo/all_memo_views.dart';
import 'package:etc/ui/screen/chagebu/car_efficiency_view.dart';
import 'package:etc/ui/screen/items/item_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 프로젝트 경로에 맞춰 import (본인의 패키지명 확인)
import 'package:etc/core/gv.dart';
import 'package:etc/ui/screen/dashboard.dart';
import 'package:etc/ui/screen/setting.dart';


void main() async {
  // 1. Flutter 엔진 및 위젯 바인딩 초기화
  // 비동기 작업(DB, SharedPreferences 등)을 수행하기 전 필수 호출
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 한국어 날짜 로케일 초기화 (달력, 날짜 포맷팅용)
  await initializeDateFormatting('ko_KR', null);

  // 3. SQLite 데이터베이스 초기화 및 설정값 로드
  // gv.dart 내부에서 DB를 열고 이메일 등의 정보를 메모리에 올립니다.
  try {
    await gv.loadSettingsFromDb();
    debugPrint("✅ 설정 로드 완료: ${gv.email}");
  } catch (e) {
    debugPrint("🚨 설정 로드 실패: $e");
  }

  //
  bool hasEmail = gv.email != "guest@gmail.com" && gv.email.isNotEmpty;

  runApp(MyDailyLogApp(hasEmail: hasEmail));
}

class MyDailyLogApp extends StatelessWidget {
  final bool hasEmail;

  // 생성자에서 hasEmail을 필수로 전달받음
  const MyDailyLogApp({super.key, required this.hasEmail});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EmotionTrashCan',

      // --- 한국어 로컬라이징 설정 ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),

      // --- 앱 전체 테마 (다크 모드 고정) ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // 딥 다크 배경
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // --- 경로(Routes) 설정 ---
      // DashboardView에서 Navigator.pushNamed를 쓰려면 여기서 등록해야 함
      initialRoute: hasEmail ? '/' : '/settings',
      routes: {
        '/': (context) => const Dashboard(),
        '/settings': (context) => const SettingsScreen(isFirstTime: false),
        //'/daily_log': (context) => const DailyLogScreen(), // 바로 여기!
        '/car_view': (context) => const CarEfficiencyView(), // 나중에 차계부 파일 만들면 주석 해제
        '/memo_view': (context) => const AllMemoViews(userId: 'cargotmon@gmail.com', listUrl: '',),
        '/item_view': (context) => const ItemListScreen(),
        //'/money_view': (context) => const MoneyDalView(),    // MoneyDalView
      },

      // initialRoute를 사용하므로 home 속성은 생략하거나 '/'와 동일하게 설정
      // home: hasEmail ? const DashboardView() : const SettingsScreen(isFirstTime: true),
    );
  }
}

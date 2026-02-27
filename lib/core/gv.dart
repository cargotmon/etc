// lib/core/gv.dart
import '/server/control/database_helper.dart';

class gv {
  static String email = "입력";
  static String get userId => email.contains('@') ? email.split('@')[0] : email;

  static bool doSaveServer = false;
  static bool doSaveLocal = true;

  // 앱 시작 시 호출
  static Future<void> loadSettingsFromDb() async {
    final List<Map<String, dynamic>> settings = await DatabaseHelper.instance.getAllSettings();
    for (var row in settings) {
      if (row['key'] == 'user_email') {
        email = row['value'];
      }
    }
  }

  // 로그인 시 호출
  static Future<void> updateEmail(String newEmail) async {
    email = newEmail;
    await DatabaseHelper.instance.saveSetting('user_email', newEmail);
  }
}

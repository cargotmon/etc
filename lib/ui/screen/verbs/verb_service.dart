import 'dart:convert';
import 'package:http/http.dart' as http;

class VerbService {
  // 베이스 URL 설정
  static const String _baseUrl = 'https://lsj.kr';
  static const String _subUrl = '/nexa/get_verbs_quiz.php';

  /// 1. 랜덤 동사 데이터 가져오기 (학습/게임용)
  /// [limit] 파라미터로 몇 개를 가져올지 정함 (기본 10개)
  Future<List<Map<String, dynamic>>> fetchVerbQuizzes({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_subUrl?limit=$limit'),
      );

      if (response.statusCode == 200) {
        // PHP 응답 구조: {"ErrorCode": 0, "data": [...]}
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody['ErrorCode'] == 0) {
          return List<Map<String, dynamic>>.from(responseBody['data'] ?? []);
        } else {
          print('Server Error: ${responseBody['ErrorMsg']}');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Verb Fetch Exception: $e');
    }
    return []; // 에러 시 빈 리스트 반환
  }

// 💡 나중에 필요할 '정답 체크'나 '학습 완료 기록' 로직을 여기 추가하면 바이브 완성!
}

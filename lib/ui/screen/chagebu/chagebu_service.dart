import 'dart:convert';
import 'package:http/http.dart' as http;

class ChagebuService {
  // 베이스 URL 설정 (본인 서버 주소 확인!)
  //https://lsj.kr/nexa/get_car_efficiency.php?userid=coxycat
  static const String _baseUrl = 'https://lsj.kr/nexa/get_car_efficiency.php';

  /// 차량별 연비 및 주유 기록 가져오기
  Future<List<Map<String, dynamic>>> fetchCarEfficiency(String userId) async {
    try {
      //userId = "coxycat";
      final response = await http.get(
        Uri.parse('$_baseUrl?userid=$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody['ErrorCode'] == 0) {
          // PHP에서 준 data 리스트를 반환
          return List<Map<String, dynamic>>.from(responseBody['data'] ?? []);
        } else {
          print('차계부 서버 에러: ${responseBody['ErrorMsg']}');
        }
      } else {
        print('HTTP 에러: ${response.statusCode}');
      }
    } catch (e) {
      print('차계부 데이터 통신 예외: $e');
    }
    return []; // 에러 발생 시 빈 리스트 반환
  }


  Future<bool> saveChagebu(Map<String, dynamic> saveData) async {
    try {
      final response = await http.post(
        Uri.parse('https://lsj.kr/nexa/save_chagebu.php'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(saveData),
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return res['ErrorCode'] == 0;
      }
      return false;
    } catch (e) {
      print("저장 실패: $e");
      return false;
    }
  }

  /// 차계부 기록 삭제 (PK: userid, car_nm, dttm)
  Future<bool> deleteChagebu(Map<String, dynamic> deleteData) async {
    try {
      final response = await http.post(
        // 💡 삭제 전용 PHP 파일 호출!
        Uri.parse('https://lsj.kr/nexa/delete_chagebu.php'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(deleteData),
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return res['ErrorCode'] == 0;
      }
      return false;
    } catch (e) {
      print("삭제 서비스 통신 에러: $e");
      return false;
    }
  }


// 추후 정비 기록이나 소모품 교체 주기 로직을 여기에 추가하면 바이브 완성!
}

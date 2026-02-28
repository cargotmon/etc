// lib/server/service/settings_service.dart
import 'package:etc/core/gv.dart';
import 'package:etc/server/service/google/google_service.dart'; // 기존 구글 서비스 활용
import 'package:googleapis/drive/v3.dart' as drive;

class SettingsService {
  final GoogleDriveService _driveService = GoogleDriveService();

  // 1. 이메일 및 설정 저장
  Future<void> saveBasicConfig(String email) async {
    await gv.updateEmail(email);
    // 추가적인 saveLocal, saveServer 옵션 처리 로직도 여기 포함
  }

  // 2. 드라이브 백업 파일 목록 가져오기
  Future<List<drive.File>> getBackupHistory() async {
    return await _driveService.getBackupFileList();
  }

  // 3. 현재 SQLite DB 파일 업로드 실행
  Future<void> runDbBackup() async {
    await _driveService.syncDatabaseToGeneralDrive();
  }

  // lib/server/service/settings_service.dart 에 추가
  Future<void> deleteBackupFile(String fileId) async {
    // 기존 GoogleDriveService의 삭제 메서드 호출
    // 만약 삭제 메서드가 없다면 driveApi.files.delete(fileId)를 실행하게 됩니다.
    await _driveService.deleteFileFromDrive(fileId);
  }

  /// [Bypass 함수] UI에서 요청을 받아 실제 구글 드라이브 서비스로 전달합니다.
  Future<bool> restoreDatabaseFromDrive({String? fileId}) async {
    try {
      // 실제 구현체인 GoogleDriveService의 함수를 그대로 호출(Bypass)하여 리턴
      return await _driveService.restoreDatabaseFromDrive(fileId: fileId);
    } catch (e) {
      print("🚨 [SettingsService] 복구 바이패스 중 에러: $e");
      return false; // 에러 발생 시 실패 반환
    }
  }

}

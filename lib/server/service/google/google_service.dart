import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
//import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart'; // 💡 이 줄을 상단에 추가 (이미 있다면 패스)

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveService {
  static const String _dbFileName = "dlog.db";

  // final GoogleSignIn _googleSignIn = GoogleSignIn(
  //   // 💡 스코프가 정확한지 확인하세요. (drive.file 또는 drive)
  //   scopes: [drive.DriveApi.driveFileScope],
  // );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file', // 👈 '모든' 파일 읽기 권한
    ],
  );


  // final GoogleSignIn _googleSignIn = GoogleSignIn(
  //   scopes: [
  //     'email',
  //     drive.DriveApi.driveReadonlyScope, // 👈 이걸로 변경 (모든 파일 읽기 권한)
  //   ],
  // );

  // --- [1. 백업 함수] ---
  Future<String?> syncDatabaseToGeneralDrive() async {
    try {
      print("🚀 [Backup] 구글 로그인 시작...");
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        print("⚠️ [Backup] 사용자가 로그인을 취소했습니다.");
        return null;
      }
      print("✅ [Backup] 로그인 성공: ${account.email}");

      final authHeaders = await account.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      // --- 수정 후 (⭐ 이 방식으로 교체하세요) ---
      final dbPath = await getDatabasesPath(); // sqflite 전용 경로 가져오기
      final file = File('$dbPath/$_dbFileName');

      print("📂 [Backup] 로컬 파일 경로: ${file.path}");
      if (!await file.exists()) {
        print("❌ [Backup] 에러: 로컬 DB 파일을 찾을 수 없습니다.");
        throw Exception("로컬 DB 파일을 찾을 수 없습니다.");
      }

      String timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      String fileName = "DLog_$timestamp.db";
      print("📤 [Backup] 업로드 준비 중: $fileName (${await file.length()} bytes)");

      final driveFile = drive.File();
      driveFile.name = fileName;

      final media = drive.Media(file.openRead(), await file.length());
      final result = await driveApi.files.create(driveFile, uploadMedia: media);

      print("🎉 [Backup] 업로드 완료! File ID: ${result.id}");
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    } catch (e, stacktrace) {
      print("🚨 [Backup] 치명적 에러 발생: $e");
      print("📜 스택트레이스: $stacktrace");
      rethrow;
    }
  }

  // --- [2. 복구 함수] ---
  // --- [2. 복구 함수 수정본] ---
  // 인자에 {String? fileId} 를 추가하여 선택적 호출이 가능하게 합니다.
  Future<bool> restoreDatabaseFromDrive({String? fileId}) async {
    try {
      print("🚀 [Restore] 구글 로그인 시작...");
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      String targetFileId;

      // 만약 UI에서 특정 fileId를 넘겨줬다면 해당 ID 사용
      if (fileId != null) {
        targetFileId = fileId;
        print("📥 [Restore] 선택된 파일 ID로 복구 시도: $targetFileId");
      } else {
        // fileId가 없다면 기존 방식대로 최신 파일 검색
        print("🔍 [Restore] 최신 백업 파일 자동 검색 중...");
        final fileList = await driveApi.files.list(
          q: "name contains 'DLog' and trashed = false",
          orderBy: "modifiedTime desc",
          spaces: 'drive',
          $fields: "files(id, name, modifiedTime, size)",
        );

        if (fileList.files == null || fileList.files!.isEmpty) {
          throw Exception("구글 드라이브에서 백업 파일을 찾을 수 없습니다.");
        }
        targetFileId = fileList.files!.first.id!;
      }

      // 파일 다운로드 시작
      final response = await driveApi.files.get(
          targetFileId,
          downloadOptions: drive.DownloadOptions.fullMedia
      ) as drive.Media;

      final dbPath = await getDatabasesPath();
      final localFile = File('$dbPath/$_dbFileName');

      final List<int> dataStore = [];
      await for (final data in response.stream) {
        dataStore.addAll(data);
      }

      await localFile.writeAsBytes(dataStore, flush: true);
      print("✅ [Restore] 복구 성공! ID: $targetFileId");

      return true;
    } catch (e) {
      print("🚨 [Restore] 에러: $e");
      rethrow;
    }
  }


  Future<List<drive.File>> getBackupFileList() async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();
      if (account == null) return [];

      final authHeaders = await account.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      // DLog가 포함된 파일 목록 가져오기
      final fileList = await driveApi.files.list(
        q: "name contains 'DLog' and trashed = false",
        orderBy: "modifiedTime desc",
        spaces: 'drive',
        $fields: "files(id, name, modifiedTime, size)",
      );

      return fileList.files ?? [];
    } catch (e) {
      print("🚨 목록 가져오기 실패: $e");
      return [];
    }
  }


  // google_service.dart 내부에 추가
  Future<void> deleteFileFromDrive(String fileId) async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) return;

      final driveApi = drive.DriveApi(GoogleAuthClient(await account.authHeaders));
      await driveApi.files.delete(fileId);
      print("🗑️ [Delete] 파일 삭제 완료: $fileId");

    } catch (e) {

      print("🚨 [Delete] 에러: $e");
      rethrow;
    }
  }


}

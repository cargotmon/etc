import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:etc/core/gv.dart';

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
  static const String _dbFileName = "etc.db";

  // 💡 수정된 스코프: 'drive.file'(쓰기) + 'drive.readonly'(남이 올린 파일 읽기)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    //serverClientId: '1038070182938-foc7s7kq5s3r79aes602vhksta5l23le.apps.googleusercontent.com',
    //serverClientId: '478754292304-kd3lkmjhsla8t6j2mvguh3uq6tr1b169.apps.googleusercontent.com',
    //serverClientId: '478754292304-kd3lkmjhsla8t6j2mvguh3uq6tr1b169.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive',        // 전체 etc 리스트
      //'https://www.googleapis.com/auth/drive.file',   이앱에서 만든거만 리스트업
    ],
  );

  // --- [로그아웃 함수] ---
  // UI 처리는 호출한 곳(Screen)에서 SnackBar를 띄우도록 bool을 반환하게 수정했습니다.
  Future<bool> handleSignOut() async {
    try {
      await _googleSignIn.signOut();
      // 완전히 연결을 끊으려면 아래 주석 해제 (다시 로그인 시 계정 선택창 강제 호출)
      await _googleSignIn.disconnect();

      await gv.updateEmail("guest@gmail.com");

      print("✅ [Auth] 로그아웃 성공");
      return true;

    } catch (e) {
      debugPrint("❌ [Auth] 로그아웃 에러: $e");
      return false;
    }
  }

  // --- [1. 백업 함수] ---
  Future<String?> syncDatabaseToGeneralDrive() async {
    try {
      print("🚀 [Backup] 구글 로그인 시도...");
      // 기존 세션이 꼬일 수 있으므로 필요시 signOut 후 signIn 하거나 silent 사용
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      final dbPath = await getDatabasesPath();
      final file = File('$dbPath/$_dbFileName');

      if (!await file.exists()) throw Exception("로컬 DB 파일을 찾을 수 없습니다.");

      String timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      String fileName = "etc_$timestamp.db";

      final driveFile = drive.File();
      driveFile.name = fileName;

      final media = drive.Media(file.openRead(), await file.length());
      await driveApi.files.create(driveFile, uploadMedia: media);

      print("🎉 [Backup] 업로드 완료: $fileName");
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    } catch (e) {
      print("🚨 [Backup] 에러: $e");
      rethrow;
    }
  }

  // --- [2. 복구 함수] ---
  Future<bool> restoreDatabaseFromDrive({String? fileId}) async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));

      String? targetFileId = fileId;

      if (targetFileId == null) {
        final fileList = await driveApi.files.list(
          q: "name contains 'etc' and trashed = false",
          orderBy: "modifiedTime desc",
          spaces: 'drive',
        );
        if (fileList.files == null || fileList.files!.isEmpty) throw Exception("파일 없음");
        targetFileId = fileList.files!.first.id;
      }

      final response = await driveApi.files.get(targetFileId!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final dbPath = await getDatabasesPath();
      final localFile = File('$dbPath/$_dbFileName');

      final List<int> dataStore = [];
      await for (final data in response.stream) { dataStore.addAll(data); }
      await localFile.writeAsBytes(dataStore, flush: true);

      return true;
    } catch (e) {
      print("🚨 [Restore] 에러: $e");
      return false;
    }
  }

  // --- [3. 목록 가져오기] ---
  Future<List<drive.File>> getBackupFileList() async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) return [];

      final driveApi = drive.DriveApi(GoogleAuthClient(await account.authHeaders));
      final fileList = await driveApi.files.list(
        q: "name contains 'etc' and trashed = false",
        orderBy: "modifiedTime desc",
        spaces: 'drive',
        $fields: "files(id, name, modifiedTime, size)",
      );

      return fileList.files ?? [];
    } catch (e) {
      print("🚨 목록 로드 에러: $e");
      return [];
    }
  }

  // --- [4. 삭제 함수] ---
  Future<void> deleteFileFromDrive(String fileId) async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) return;

      final driveApi = drive.DriveApi(GoogleAuthClient(await account.authHeaders));
      await driveApi.files.delete(fileId);
    } catch (e) {
      rethrow;
    }
  }


}

import 'dart:convert';

import 'package:etc/server/control/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:etc/server/service/settings_service.dart';
import 'package:etc/core/gv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstTime;
  const SettingsScreen({super.key, this.isFirstTime = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  final _emailController = TextEditingController();

  bool _isSyncing = false;
  List<drive.File> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _emailController.text = (gv.email == "없음") ? "" : gv.email;
    _loadBackupHistory();
  }

  // 1. 백업 목록 불러오기
  Future<void> _loadBackupHistory() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);
    try {
      final files = await _service.getBackupHistory();
      setState(() => _backupFiles = files);
    } catch (e) {
      debugPrint("백업 목록 로드 실패: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }


  Future<void> _handleBackupMariaToLocal() async {
    // 1. 로딩 표시 (선택 사항)
    debugPrint("🚀 MariaDB -> 로컬 SQLite 마이그레이션 시작...");

    try {
      // 2. PHP 서버 호출 (본인 서버 URL로 수정 필수)
      //                  https://lsj.kr/nexa/get_all_daily_logs.php?userid=coxycat@naver.com
      final String url = "https://lsj.kr/nexa/get_all_daily_logs.php?userid=coxycat@naver.com";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['ErrorCode'] == 0) {
          List<dynamic> serverLogs = jsonResponse['data'];
          final db = await DatabaseHelper.instance.database;

          // 3. 트랜잭션을 사용하여 데이터 무결성 및 속도 확보 [sqflite Transaction](https://pub.dev)
          await db.transaction((txn) async {
            for (var log in serverLogs) {
              String logUuid = log['uuid'] ?? const Uuid().v4();

              // 💡 MariaDB의 med_time 문자열(예: '6:35~ 12:35')을 SQLite 컬럼에 분배
              List<String> times = (log['med_time'] ?? "").toString().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

              // 4. 메인 로그 저장 (daily_logs)
              await txn.insert(
                'daily_logs',
                {
                  'uuid': logUuid,
                  //'userid': log['userid'],
                  'userid': "cargotmon@gmail.com",
                  'date': log['date'], // MariaDB의 'day' 컬럼
                  'memo': log['memo'],
                  'med_time1': times.isNotEmpty ? times[0] : null,
                  'med_time2': times.length > 1 ? times[1] : null,
                  'med_time3': times.length > 2 ? times[2] : null,
                  'weather': log['weather'],
                  'mood': log['mood'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace, // 💡 중복 시 덮어쓰기 (Merge)
              );

              // 5. 지출 상세 내역 분리 저장 (expenses 테이블)
              if (log['expense_data'] != null && log['expense_data'].toString().isNotEmpty) {
                // 기존 해당 UUID의 지출 데이터 삭제 후 재삽입
                await txn.delete('expenses', where: 'log_uuid = ?', whereArgs: [logUuid]);

                try {
                  List<dynamic> expenseList = jsonDecode(log['expense_data']);
                  for (var exp in expenseList) {
                    await txn.insert('expenses', {
                      'log_uuid': logUuid,
                      'item': exp['item'],
                      'price': int.tryParse(exp['price'].toString()) ?? 0,
                    });
                  }
                } catch (e) {
                  debugPrint("❌ 지출 데이터 파싱 에러 (날짜: ${log['date']}): $e");
                }
              }
            }
          });

          debugPrint("✅ 마이그레이션 완료: ${serverLogs.length}건 처리됨");

          // 6. UI 갱신 (현재 화면의 데이터를 다시 불러오는 함수 호출)
          if (mounted) {
            setState(() {
              // _loadLocalData(); // 로컬 DB에서 다시 읽어오는 로직 실행
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${serverLogs.length}건의 데이터를 가져왔습니다.")),
            );
          }
        }
      } else {
        throw Exception("서버 응답 에러: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ 마이그레이션 중 오류 발생: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("데이터를 가져오는 중 오류가 발생했습니다.")),
        );
      }
    }
  }

  Future<void> _handleBackupToMaria() async {
    setState(() => _isSyncing = true);
    try {
      await _service.runDbBackup();
      await _loadBackupHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ 구글 드라이브 백업 완료!"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ 백업 실패: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // 2. DB 백업 실행
  Future<void> _handleBackup() async {
    setState(() => _isSyncing = true);
    try {
      await _service.runDbBackup();
      await _loadBackupHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ 구글 드라이브 백업 완료!"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ 백업 실패: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // 3. DB 복구 확인 팝업
  void _showRestoreDialog(String fileId, String dateStr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("데이터 복구", style: TextStyle(color: Colors.white)),
        content: Text("[$dateStr] 백업본으로 복구할까요?\n현재 기기의 데이터는 삭제됩니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              Navigator.pop(context);
              _executeRestore(fileId); // 복구 실행 함수 호출
            },
            child: const Text("복구하기", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 4. 실제 복구 실행 로직 (요청하신 함수 규격 적용)
  Future<void> _executeRestore(String fileId) async {
    setState(() => _isSyncing = true);
    try {
      // 💡 [핵심] 네임드 파라미터 fileId 전달 및 리턴값(bool) 확인
      bool isSuccess = await _service.restoreDatabaseFromDrive(fileId: fileId);

      if (mounted) {
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ 복구 성공! 변경사항 적용을 위해 앱을 재시작하세요."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("⚠️ 복구 실패: 파일 처리 중 오류가 발생했습니다."))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ 에러: $e"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(widget.isFirstTime ? "초기 설정" : "설정 & 백업"),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle("사용자 계정"),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration("이메일 주소 (ID)", Icons.email),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              try {
                // 1. 저장 시도 (로딩 인디케이터를 띄우는 것이 좋습니다)
                await _service.saveBasicConfig(_emailController.text);
                debugPrint("저장 성공!"); // 로그 확인용
              } catch (e) {
                debugPrint("저장 중 에러 발생: $e");
                // 에러가 나도 화면을 넘길지, 여기서 멈출지 결정
              }

              if (mounted) {
                // 💡 첫 방문 여부와 상관없이 무조건 대시보드로 이동하게 수정
                debugPrint('gogo dash board');
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text("기본 설정 저장", style: TextStyle(color: Colors.white)),
          ),

          const Divider(height: 60, color: Colors.white24),

          _buildSectionTitle("마리아서버"),
          _isSyncing
              ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
              : ElevatedButton.icon(
            onPressed: _handleBackupMariaToLocal,
            icon: const Icon(Icons.cloud_download),
            label: const Text("maria to local"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
          ),
          _isSyncing
              ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
              : ElevatedButton.icon(
            onPressed: _handleBackupToMaria,
            icon: const Icon(Icons.cloud_upload),
            label: const Text("local => maria"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700),
          ),

          const Divider(height: 60, color: Colors.white24),

          _buildSectionTitle("구글 드라이브 백업 (SQLite)"),
          _isSyncing
              ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
              : ElevatedButton.icon(
            onPressed: _handleBackup,
            icon: const Icon(Icons.cloud_upload),
            label: const Text("지금 바로 DB 백업하기"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
          ),

          const SizedBox(height: 30),
          const Text("최근 백업 이력 (클릭:복구 / 밀어서:삭제)", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),

          // 백업 리스트 영역
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: _backupFiles.isEmpty && !_isSyncing
                ? const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: Text("기록 없음", style: TextStyle(color: Colors.white38))),
            )
                : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backupFiles.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final file = _backupFiles[index];
                final fId = file.id ?? "";
                final dateStr = file.modifiedTime != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format(file.modifiedTime!.toLocal())
                    : "알 수 없음";

                return Dismissible(
                  key: Key(fId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    setState(() { _backupFiles.removeAt(index); });
                    await _service.deleteBackupFile(fId);
                  },
                  child: ListTile(
                    onTap: () => _showRestoreDialog(fId, dateStr), // 💡 클릭 시 복구 팝업
                    leading: const Icon(Icons.storage, color: Colors.amber, size: 22),
                    title: Text(file.name ?? "DB 파일", style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text("백업: $dateStr", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: const Icon(Icons.history, color: Colors.blueAccent, size: 18),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
  );

  InputDecoration _buildInputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    prefixIcon: Icon(icon, color: Colors.indigoAccent),
  );
}

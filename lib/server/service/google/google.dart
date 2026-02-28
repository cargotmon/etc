import 'package:flutter/material.dart';
import 'google_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  bool _isSyncing = false;
  String _lastSyncTime = "기록 확인 중...";
  List<drive.File> _backupFiles = [];

  final GoogleDriveService _driveService = GoogleDriveService();

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  // --- [데이터 새로고침] ---
  Future<void> _refreshHistory() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);
    try {
      final files = await _driveService.getBackupFileList();
      setState(() {
        _backupFiles = files;
        if (files.isNotEmpty) {
          final lastDate = files.first.modifiedTime?.toLocal();
          _lastSyncTime = lastDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(lastDate) : "기록 없음";
        } else {
          _lastSyncTime = "백업 기록 없음";
        }
      });
    } catch (e) {
      print("목록 불러오기 실패: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- [백업 실행] ---
  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      await _driveService.syncDatabaseToGeneralDrive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 구글 드라이브 백업 완료!'), backgroundColor: Colors.green),
        );
      }
      await _refreshHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 백업 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- [복구 실행] ---
  Future<void> _handleRestore(drive.File file) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('데이터 복구', style: TextStyle(color: Colors.white)),
        content: Text('[${file.name}]\n데이터를 복구하시겠습니까?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('복구', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSyncing = true);
    try {
      await _driveService.restoreDatabaseFromDrive(fileId: file.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 복구 성공! 앱을 재시작해 주세요.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 복구 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- [삭제 실행] ---
  Future<void> _handleDelete(drive.File file) async {
    try {
      await _driveService.deleteFileFromDrive(file.id!);
      setState(() {
        _backupFiles.removeWhere((f) => f.id == file.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ 파일이 삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 삭제 실패: $e'), backgroundColor: Colors.redAccent),
        );
      }
      _refreshHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF000000); // 완전한 블랙 배경

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: const Text('데이터 백업/복구', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _refreshHistory, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
        elevation: 0,
      ),
      // 💡 SafeArea를 추가하여 상/하단 시스템 영역 침범을 방지합니다.
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Icon(_isSyncing ? Icons.sync : Icons.cloud_done, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 15),

            // 상단 요약 정보
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('최근 백업: $_lastSyncTime', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            const SizedBox(height: 25),

            // 백업 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSync,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('지금 새 백업 만들기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 35),

            // 히스토리 제목 영역
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text("백업 히스토리", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Spacer(),
                  Text("← 밀어서 삭제", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Divider(color: Colors.white10, indent: 20, endIndent: 20, height: 20),

            // 리스트 영역
            Expanded(
              child: _backupFiles.isEmpty
                  ? Center(child: Text(_isSyncing ? "불러오는 중..." : "기록이 없습니다.", style: const TextStyle(color: Colors.white38)))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _backupFiles.length,
                itemBuilder: (context, index) {
                  final file = _backupFiles[index];
                  final date = file.modifiedTime?.toLocal();

                  return Dismissible(
                    key: Key(file.id!),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text("삭제 확인", style: TextStyle(color: Colors.white)),
                          content: const Text("구글 드라이브에서 백업 파일을 영구 삭제하시겠습니까?", style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("삭제", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) => _handleDelete(file),
                    child: Card(
                      color: Colors.white.withOpacity(0.05),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.blueAccent),
                        title: Text(file.name ?? "Backup File", style: const TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: Text(
                          date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : "날짜 없음",
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.restore_page, color: Colors.white24, size: 20),
                        onTap: () => _handleRestore(file),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 최하단 주의 사항 (SafeArea 내부)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: const Text(
                '※ 주의: 파일 선택 시 현재 기기의 데이터가 백업본으로 교체됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

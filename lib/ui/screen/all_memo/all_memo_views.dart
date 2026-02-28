import 'package:etc/server/service/memo/get_all_memo.dart';
import 'package:flutter/material.dart';

class AllMemoViews extends StatefulWidget {
  final String userId;
  final String listUrl;
  const AllMemoViews({super.key, required this.userId, required this.listUrl});

  @override
  State<AllMemoViews> createState() => _AllMemoViewsScreenState();
}

class _AllMemoViewsScreenState extends State<AllMemoViews> {
  late MemoService _memoService;

  @override
  void initState() {
    super.initState();
    _memoService = MemoService(userId: widget.userId, listUrl: widget.listUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("전체 기록 모아보기")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // ✅ 서비스의 로컬 조회 함수 호출
        future: _memoService.fetchLocalLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(child: Text("데이터 없음", style: TextStyle(color: Colors.white)));

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return Card(
                color: const Color(0xFF1C1C1E),
                child: ListTile(
                  title: Text(item['date'] ?? "", style: const TextStyle(color: Colors.indigoAccent)),
                  subtitle: Text(item['memo'] ?? "", style: const TextStyle(color: Colors.white70)),
                  trailing: Text(item['mood'] ?? "", style: const TextStyle(color: Colors.pinkAccent)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
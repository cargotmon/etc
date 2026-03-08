class LocModel {
  final int? sn;
  final String uuid;
  final String userEmail;
  final String loc1;
  final String? loc2;
  final String? memo;
  final String delYn; // 🗑️ 삭제 여부 필드 추가
  final String syncYn;

  LocModel({
    this.sn,
    required this.uuid,
    required this.userEmail,
    required this.loc1,
    this.loc2,
    this.memo,
    this.delYn = 'N', // 기본값 'N'
    this.syncYn = 'N',
  });

  // DB에서 읽어올 때 (Map -> Object)
  factory LocModel.fromMap(Map<String, dynamic> map) => LocModel(
    sn: map['sn'],
    uuid: map['uuid'],
    userEmail: map['user_email'],
    loc1: map['loc1'],
    loc2: map['loc2'],
    memo: map['memo'],
    delYn: map['del_yn'] ?? 'N', // null 방지 처리
    syncYn: map['sync_yn'] ?? 'N',
  );

  // DB에 저장할 때 (Object -> Map)
  Map<String, dynamic> toMap() => {
    'sn': sn,
    'uuid': uuid,
    'user_email': userEmail,
    'loc1': loc1,
    'loc2': loc2,
    'memo': memo,
    'del_yn': delYn, // 맵에 포함
    'sync_yn': syncYn,
  };
}

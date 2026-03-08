class ItemModel {
  final int? sn;
  final String uuid;
  final String name;
  final String? category;
  final int? locSn;
  final String ownerEmail;
  final String holderEmail;
  final int ea;
  final String? buyDttm;
  final String? memo;
  final String? imgPath;
  final String delYn;
  final String syncYn;

  ItemModel({
    this.sn,
    required this.uuid,
    required this.name,
    this.category,
    this.locSn,
    required this.ownerEmail,
    required this.holderEmail,
    this.ea = 1,
    this.buyDttm,
    this.memo,
    this.imgPath,
    this.delYn = 'N',
    this.syncYn = 'N',
  });

  // DB에서 읽어올 때 (Map -> Object)
  factory ItemModel.fromMap(Map<String, dynamic> map) => ItemModel(
    sn: map['sn'],
    uuid: map['uuid'],
    name: map['name'],
    category: map['category'],
    locSn: map['loc_sn'],
    ownerEmail: map['owner_email'],
    holderEmail: map['holder_email'],
    ea: map['ea'] ?? 1,
    buyDttm: map['buy_dttm'],
    memo: map['memo'],
    imgPath: map['img_path'],
    delYn: map['del_yn'] ?? 'N',
    syncYn: map['sync_yn'] ?? 'N',
  );

  // DB에 저장할 때 (Object -> Map)
  Map<String, dynamic> toMap() => {
    'sn': sn,
    'uuid': uuid,
    'name': name,
    'category': category,
    'loc_sn': locSn,
    'owner_email': ownerEmail,
    'holder_email': holderEmail,
    'ea': ea,
    'buy_dttm': buyDttm,
    'memo': memo,
    'img_path': imgPath,
    'del_yn': delYn,
    'sync_yn': syncYn,
  };
}

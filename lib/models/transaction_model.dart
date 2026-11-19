class TransactionModel {
  final String id;
  final String title;
  final String? description;
  final int amount;
  final String type; // 'income' | 'expense' | 'transfer'
  final String accountId;
  final String? targetAccountId;
  final String createdAt;
  final String? category;
  final int fee;
  final String? img;
  final String? deletedAt;

  TransactionModel({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.type,
    required this.accountId,
    this.targetAccountId,
    required this.createdAt,
    this.category,
    this.fee = 0,
    this.img,
    this.deletedAt,
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    String? description,
    int? amount,
    String? type,
    String? accountId,
    String? targetAccountId,
    String? createdAt,
    String? category,
    int? fee,
    String? img,
    String? deletedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      fee: fee ?? this.fee,
      img: img ?? this.img,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type,
      'accountId': accountId,
      'targetAccountId': targetAccountId,
      'createdAt': createdAt,
      'category': category,
      'fee': fee,
      'img': img ?? '',
    };
    if (deletedAt != null) {
      map['deletedAt'] = deletedAt;
    }
    return map;
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'expense',
      accountId: map['accountId']?.toString() ?? '',
      targetAccountId: map['targetAccountId']?.toString(),
      createdAt: map['createdAt']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      category: map['category']?.toString(),
      fee: (map['fee'] as num?)?.toInt() ?? 0,
      img: map['img']?.toString(),
      deletedAt: map['deletedAt']?.toString(),
    );
  }

  DateTime get dateTime {
    final asInt = int.tryParse(createdAt);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.tryParse(createdAt) ?? DateTime.now();
  }
}

class GroupedTransaction {
  final String date;
  final int timestamp;
  final int total;
  final List<TransactionModel> transactions;

  GroupedTransaction({
    required this.date,
    required this.timestamp,
    required this.total,
    required this.transactions,
  });
}

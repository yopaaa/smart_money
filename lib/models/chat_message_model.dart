import 'transaction_model.dart';

class ChatMessageModel {
  final String id;
  final String sender; // 'user' | 'assistant'
  final String message;
  final int timestamp;
  final bool isVoice;
  final List<TransactionModel> transactions;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
    this.isVoice = false,
    this.transactions = const [],
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'message': message,
      'timestamp': timestamp,
      'isVoice': isVoice,
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    final rawTxs = map['transactions'] as List<dynamic>? ?? [];
    return ChatMessageModel(
      id: map['id']?.toString() ?? '',
      sender: map['sender']?.toString() ?? 'user',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp'] is int
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch,
      isVoice: map['isVoice'] == true || map['isVoice'] == 1,
      transactions: rawTxs
          .map((t) => TransactionModel.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }
}

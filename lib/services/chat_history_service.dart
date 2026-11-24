import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';

class ChatHistoryService {
  static final ChatHistoryService instance = ChatHistoryService._();
  ChatHistoryService._();

  static const String settingChatHistoryKey = '@chat_history';

  List<ChatMessageModel>? _cachedMessages;

  Future<List<ChatMessageModel>> getMessages() async {
    if (_cachedMessages != null) {
      return List.unmodifiable(_cachedMessages!);
    }

    try {
      final raw =
          await DatabaseHelper.instance.getSetting(settingChatHistoryKey);
      if (raw != null) {
        List<dynamic> list;
        if (raw is List) {
          list = raw;
        } else if (raw is String) {
          list = jsonDecode(raw) as List<dynamic>;
        } else {
          list = [];
        }
        _cachedMessages = list
            .map((item) => ChatMessageModel.fromMap(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        return List.unmodifiable(_cachedMessages!);
      }
    } catch (e) {
      debugPrint('ChatHistoryService getMessages error: $e');
    }

    _cachedMessages ??= [];
    return List.unmodifiable(_cachedMessages!);
  }

  Future<void> addMessage(ChatMessageModel message) async {
    final current = (await getMessages()).toList();
    current.add(message);
    _cachedMessages = current;
    await _saveToStorage();
  }

  Future<void> addVoiceTransactionChat({
    required String transcript,
    required List<TransactionModel> savedTransactions,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final userMsg = ChatMessageModel(
      id: const Uuid().v4(),
      sender: 'user',
      message: transcript,
      timestamp: now,
      isVoice: true,
    );

    final summaryText = savedTransactions.length == 1
        ? 'Berhasil mencatat 1 transaksi:'
        : 'Berhasil mencatat ${savedTransactions.length} transaksi:';

    final assistantMsg = ChatMessageModel(
      id: const Uuid().v4(),
      sender: 'assistant',
      message: summaryText,
      timestamp: now + 50,
      isVoice: true,
      transactions: savedTransactions,
    );

    final current = (await getMessages()).toList();
    current.add(userMsg);
    current.add(assistantMsg);
    _cachedMessages = current;
    await _saveToStorage();
  }

  Future<void> clearHistory() async {
    _cachedMessages = [];
    try {
      await DatabaseHelper.instance.saveSetting(settingChatHistoryKey, []);
    } catch (e) {
      debugPrint('ChatHistoryService clearHistory error: $e');
    }
  }

  Future<void> _saveToStorage() async {
    if (_cachedMessages == null) return;
    try {
      final serialized = _cachedMessages!.map((m) => m.toMap()).toList();
      await DatabaseHelper.instance
          .saveSetting(settingChatHistoryKey, serialized);
    } catch (e) {
      debugPrint('ChatHistoryService _saveToStorage error: $e');
    }
  }
}

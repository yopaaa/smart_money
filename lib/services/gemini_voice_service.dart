import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/currency_model.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';

/// Represents a single transaction parsed from voice by Gemini AI.
class ParsedVoiceTransaction {
  final String id;
  String title;
  int amount;
  String type; // 'expense' | 'income' | 'transfer'
  String? accountId;
  String? accountName;
  String? categoryId;
  String? categoryName;
  String? targetAccountId;
  String? targetAccountName;
  DateTime dateTime;
  String description;

  ParsedVoiceTransaction({
    String? id,
    required this.title,
    required this.amount,
    required this.type,
    this.accountId,
    this.accountName,
    this.categoryId,
    this.categoryName,
    this.targetAccountId,
    this.targetAccountName,
    DateTime? dateTime,
    this.description = '',
  })  : id = id ?? const Uuid().v4(),
        dateTime = dateTime ?? DateTime.now();

  ParsedVoiceTransaction copyWith({
    String? id,
    String? title,
    int? amount,
    String? type,
    String? accountId,
    String? accountName,
    String? categoryId,
    String? categoryName,
    String? targetAccountId,
    String? targetAccountName,
    DateTime? dateTime,
    String? description,
  }) {
    return ParsedVoiceTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      targetAccountName: targetAccountName ?? this.targetAccountName,
      dateTime: dateTime ?? this.dateTime,
      description: description ?? this.description,
    );
  }

  TransactionModel toTransactionModel() {
    return TransactionModel(
      id: id,
      title: title.isEmpty ? 'Transaksi Suara' : title,
      amount: amount > 0 ? amount : 0,
      type: type,
      accountId: accountId ?? '',
      targetAccountId: type == 'transfer' ? targetAccountId : null,
      createdAt: dateTime.millisecondsSinceEpoch.toString(),
      category: type == 'transfer' ? null : categoryId,
      description: description,
    );
  }

  factory ParsedVoiceTransaction.fromJson(
    Map<String, dynamic> json, {
    List<AccountModel>? availableAccounts,
    List<CategoryModel>? availableCategories,
    DateTime? referenceDateTime,
  }) {
    final rawTitle = json['title']?.toString() ?? 'Transaksi Suara';
    final rawAmount = (json['amount'] is num)
        ? (json['amount'] as num).toInt()
        : int.tryParse(json['amount']?.toString() ?? '0') ?? 0;

    String rawType = json['type']?.toString().toLowerCase() ?? 'expense';
    if (rawType != 'income' && rawType != 'expense' && rawType != 'transfer') {
      rawType = 'expense';
    }

    String? accountId = json['account_id']?.toString();
    String? accountName = json['account_name']?.toString();

    // Match or fallback to first available account
    if (availableAccounts != null && availableAccounts.isNotEmpty) {
      final matchedAcc = availableAccounts.firstWhere(
        (a) =>
            a.id == accountId ||
            (accountName != null &&
                a.name.toLowerCase() == accountName.toLowerCase()),
        orElse: () => availableAccounts.first,
      );
      accountId = matchedAcc.id;
      accountName = matchedAcc.name;
    }

    String? categoryId = json['category_id']?.toString();
    String? categoryName = json['category_name']?.toString();

    // Match category
    if (rawType != 'transfer' &&
        availableCategories != null &&
        availableCategories.isNotEmpty) {
      CategoryModel? matchedCat;
      try {
        matchedCat = availableCategories.firstWhere(
          (c) =>
              c.id == categoryId ||
              (categoryName != null &&
                  c.name.toLowerCase() == categoryName.toLowerCase()),
        );
      } catch (_) {
        // Fallback: match by type
        final matchingType =
            availableCategories.where((c) => c.type == rawType);
        matchedCat = matchingType.isNotEmpty ? matchingType.first : null;
      }
      if (matchedCat != null) {
        categoryId = matchedCat.id;
        categoryName = matchedCat.name;
      }
    }

    String? targetAccountId = json['target_account_id']?.toString();
    String? targetAccountName = json['target_account_name']?.toString();
    if (rawType == 'transfer' && availableAccounts != null) {
      if (targetAccountId != null || targetAccountName != null) {
        final matchedTarget = availableAccounts.where((a) =>
            a.id == targetAccountId ||
            (targetAccountName != null &&
                a.name.toLowerCase() == targetAccountName.toLowerCase()));
        if (matchedTarget.isNotEmpty) {
          targetAccountId = matchedTarget.first.id;
          targetAccountName = matchedTarget.first.name;
        }
      }
    }

    // Parse date_time
    DateTime parsedDate = referenceDateTime ?? DateTime.now();
    final rawDate = json['date_time'];
    if (rawDate != null) {
      if (rawDate is num) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt());
      } else {
        final parsed = DateTime.tryParse(rawDate.toString());
        if (parsed != null) {
          parsedDate = parsed;
        }
      }
    }

    // Parse description - must not just repeat the title, and should act as an informative marker
    String rawDesc = json['description']?.toString().trim() ?? '';
    final cleanTitleLower =
        rawTitle.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final cleanDescLower =
        rawDesc.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

    if (rawDesc.isEmpty || cleanDescLower == cleanTitleLower) {
      rawDesc = '🎙️ Transaksi Suara: $rawTitle';
    } else if (!rawDesc.startsWith('🎙️') &&
        !rawDesc.toLowerCase().contains('suara')) {
      rawDesc = '🎙️ Transaksi Suara: $rawDesc';
    }

    return ParsedVoiceTransaction(
      title: rawTitle,
      amount: rawAmount,
      type: rawType,
      accountId: accountId,
      accountName: accountName,
      categoryId: categoryId,
      categoryName: categoryName,
      targetAccountId: targetAccountId,
      targetAccountName: targetAccountName,
      dateTime: parsedDate,
      description: rawDesc,
    );
  }
}

class GeminiMissingApiKeyException implements Exception {
  final String message;
  GeminiMissingApiKeyException(
      [this.message = 'API Key Gemini belum diatur di Pengaturan.']);

  @override
  String toString() => message;
}

class GeminiApiException implements Exception {
  final String message;
  final int? statusCode;
  GeminiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class GeminiVoiceService {
  static final GeminiVoiceService instance = GeminiVoiceService._();
  GeminiVoiceService._();

  static const String settingApiKey = '@gemini_api_key';
  static const String defaultModel = 'gemini-2.5-flash';
  static const String fallbackModel = 'gemini-1.5-flash';

  String? _cachedApiKey;

  Future<String?> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    try {
      final saved = await DatabaseHelper.instance.getSetting(settingApiKey);
      if (saved != null && saved.toString().trim().isNotEmpty) {
        _cachedApiKey = saved.toString().trim();
        return _cachedApiKey;
      }
    } catch (e) {
      debugPrint('GeminiVoiceService getApiKey error: $e');
    }
    return null;
  }

  Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    _cachedApiKey = trimmed;
    await DatabaseHelper.instance.saveSetting(settingApiKey, trimmed);
  }

  Future<void> removeApiKey() async {
    _cachedApiKey = null;
    await DatabaseHelper.instance.saveSetting(settingApiKey, '');
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Tests the validity of an API key by sending a tiny ping request.
  Future<bool> testApiKey(String apiKey) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$defaultModel:generateContent?key=$apiKey',
    );

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Ping'}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 5,
      }
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return true;
    }

    // Try fallback model
    final fallbackUrl = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$fallbackModel:generateContent?key=$apiKey',
    );
    final fallbackRes = await http
        .post(
          fallbackUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    return fallbackRes.statusCode == 200;
  }

  /// Parses recorded audio into a list of structured transactions using Gemini Multimodal API.
  Future<List<ParsedVoiceTransaction>> parseAudioToTransactions({
    required File audioFile,
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required CurrencyModel currency,
    DateTime? referenceDateTime,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw GeminiMissingApiKeyException();
    }

    if (!audioFile.existsSync()) {
      throw GeminiApiException('File rekaman audio tidak ditemukan.');
    }

    final bytes = await audioFile.readAsBytes();
    if (bytes.isEmpty) {
      throw GeminiApiException('Rekaman audio kosong atau terlalu pendek.');
    }

    final base64Audio = base64Encode(bytes);
    final mimeType = _getMimeTypeForFile(audioFile.path);

    final promptText = _buildPromptInstructions(
      accounts: accounts,
      categories: categories,
      currency: currency,
      refDate: referenceDateTime ?? DateTime.now(),
    );

    return await _callGeminiApi(
      apiKey: apiKey,
      audioPart: {
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Audio,
        }
      },
      promptText: promptText,
      accounts: accounts,
      categories: categories,
      refDate: referenceDateTime ?? DateTime.now(),
    );
  }

  /// Parses plain text string into a list of structured transactions (useful for testing or fallback).
  Future<List<ParsedVoiceTransaction>> parseTextToTransactions({
    required String textPrompt,
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required CurrencyModel currency,
    DateTime? referenceDateTime,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw GeminiMissingApiKeyException();
    }

    final instructions = _buildPromptInstructions(
      accounts: accounts,
      categories: categories,
      currency: currency,
      refDate: referenceDateTime ?? DateTime.now(),
    );

    final fullPrompt = '$instructions\n\nUSER SPEECH TRANSCRIPT:\n"$textPrompt"';

    return await _callGeminiApi(
      apiKey: apiKey,
      audioPart: null,
      promptText: fullPrompt,
      accounts: accounts,
      categories: categories,
      refDate: referenceDateTime ?? DateTime.now(),
    );
  }

  Future<List<ParsedVoiceTransaction>> _callGeminiApi({
    required String apiKey,
    required Map<String, dynamic>? audioPart,
    required String promptText,
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required DateTime refDate,
  }) async {
    final parts = <Map<String, dynamic>>[];
    if (audioPart != null) {
      parts.add(audioPart);
    }
    parts.add({'text': promptText});

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      }
    };

    http.Response response;
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$defaultModel:generateContent?key=$apiKey',
      );

      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        // Fallback to gemini-1.5-flash
        final fallbackUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$fallbackModel:generateContent?key=$apiKey',
        );
        response = await http
            .post(
              fallbackUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 35));
      }
    } catch (e) {
      throw GeminiApiException('Gagal menghubungi Gemini API: $e');
    }

    if (response.statusCode != 200) {
      String errorMessage = 'Gemini API Error (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['error']?['message'] != null) {
          errorMessage = errJson['error']['message'];
        }
      } catch (_) {}
      throw GeminiApiException(errorMessage, statusCode: response.statusCode);
    }

    return _parseGeminiJsonResponse(
      response.body,
      accounts: accounts,
      categories: categories,
      refDate: refDate,
    );
  }

  List<ParsedVoiceTransaction> _parseGeminiJsonResponse(
    String responseBody, {
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required DateTime refDate,
  }) {
    final Map<String, dynamic> decoded = jsonDecode(responseBody);
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw GeminiApiException('Tidak ada hasil yang dihasilkan oleh AI.');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final contentParts =
        firstCandidate['content']?['parts'] as List<dynamic>?;
    if (contentParts == null || contentParts.isEmpty) {
      throw GeminiApiException('Respon AI kosong.');
    }

    String rawText = contentParts.first['text']?.toString().trim() ?? '';
    // Strip markdown fences if present
    if (rawText.startsWith('```json')) {
      rawText = rawText.substring(7);
    } else if (rawText.startsWith('```')) {
      rawText = rawText.substring(3);
    }
    if (rawText.endsWith('```')) {
      rawText = rawText.substring(0, rawText.length - 3);
    }
    rawText = rawText.trim();

    Map<String, dynamic> parsedJson;
    try {
      final decodedJson = jsonDecode(rawText);
      if (decodedJson is List) {
        parsedJson = {'transactions': decodedJson};
      } else if (decodedJson is Map<String, dynamic>) {
        parsedJson = decodedJson;
      } else {
        throw Exception('Bukan format JSON yang diharapkan');
      }
    } catch (e) {
      throw GeminiApiException(
        'Gagal memproses format JSON dari respon AI: $e\nRaw: $rawText',
      );
    }

    final txListJson = parsedJson['transactions'] as List<dynamic>? ?? [];
    if (txListJson.isEmpty) {
      throw GeminiApiException(
        'Tidak ada transaksi yang terdeteksi dalam suara Anda. Silakan coba bicara lebih jelas.',
      );
    }

    return txListJson.map((item) {
      final itemMap = Map<String, dynamic>.from(item as Map);
      return ParsedVoiceTransaction.fromJson(
        itemMap,
        availableAccounts: accounts,
        availableCategories: categories,
        referenceDateTime: refDate,
      );
    }).toList();
  }

  String _buildPromptInstructions({
    required List<AccountModel> accounts,
    required List<CategoryModel> categories,
    required CurrencyModel currency,
    required DateTime refDate,
  }) {
    final formattedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(refDate);
    final dayName = DateFormat('EEEE').format(refDate);

    final accountsJson = jsonEncode(
      accounts
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'type': a.type,
              })
          .toList(),
    );

    final categoriesJson = jsonEncode(
      categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'type': c.type,
              })
          .toList(),
    );

    return '''
You are an expert financial assistant for the Smart Money expense tracker app.
Analyze the user's speech audio/transcript in Indonesian (or casual Indonesian mixed with English slang).

CURRENT REFERENCE DATETIME: $formattedDate ($dayName).
ACTIVE CURRENCY: ${currency.currency} (${currency.symbol}).

AVAILABLE ACCOUNTS IN DATABASE:
$accountsJson

AVAILABLE CATEGORIES IN DATABASE:
$categoriesJson

INSTRUCTIONS:
1. The user may mention ONE OR MULTIPLE transactions in a single speech. Extract ALL valid transactions into the "transactions" array.
2. Determine "type":
   - "expense": purchases, payments, bills, buy items.
   - "income": salary, received money, selling items, profit, cash gifts.
   - "transfer": moving money between user accounts (e.g., "transfer 50rb dari BCA ke Mandiri", "top up GoPay 100rb dari BCA").
3. For transfers:
   - "account_id": ID of source account from AVAILABLE ACCOUNTS.
   - "target_account_id": ID of destination account from AVAILABLE ACCOUNTS.
   - "category_id": null.
4. For expense/income:
   - Match "account_id" to the best matching account. If not specified, default to the first available account or Cash.
   - Match "category_id" to the best matching category.
5. Understand Indonesian slang & amount terminology:
   - "k", "rebu", "rb", "ribu" = 1,000 (e.g. "25k" = 25000, "50 rebu" = 50000).
   - "seceng" = 1,000.
   - "goceng" = 5,000.
   - "ceban" = 10,000.
   - "gocap" = 50,000.
   - "cepek" = 100,000.
   - "sejeti", "juta" = 1,000,000.
   - "setengah juta" = 500,000.
6. For date_time:
   - If user mentions specific or relative dates (e.g., "kemarin", "tadi pagi", "hari minggu kemarin", "tanggal 15 lalu"), compute the exact ISO-8601 string (e.g., "YYYY-MM-DDTHH:mm:ss") relative to CURRENT REFERENCE DATETIME.
   - If no date is mentioned, use CURRENT REFERENCE DATETIME.
7. Rules for "title" vs "description":
   - "title": Short, concise, professional title (2-4 words, e.g. "Beli Bensin", "Makan Siang", "Top Up GoPay", "Gaji Bulanan").
   - "description": MUST NOT merely duplicate or echo the title! Make it informative and serve as a clear voice marker:
     * Format as: "🎙️ Transaksi Suara: [detail spesifik ucapan atau konteks transaksi]"
     * Include specific context mentioned in speech (e.g. specific item or food variant, merchant/store name, purpose, recipient, or payment method notes: e.g. "🎙️ Transaksi Suara: Kopi susu gula aren di Kopi Kenangan via QRIS BCA", "🎙️ Transaksi Suara: Pertalite untuk motor di SPBU").
     * Never output the same text as "title".
8. Output ONLY a valid JSON object matching this schema:
{
  "transactions": [
    {
      "title": "string",
      "amount": integer,
      "type": "expense" | "income" | "transfer",
      "account_id": "string",
      "account_name": "string",
      "category_id": "string" | null,
      "category_name": "string" | null,
      "target_account_id": "string" | null,
      "target_account_name": "string" | null,
      "date_time": "YYYY-MM-DDTHH:mm:ss",
      "description": "string"
    }
  ]
}
''';
  }

  String _getMimeTypeForFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4') || lower.endsWith('.aac')) {
      return 'audio/m4a';
    } else if (lower.endsWith('.wav')) {
      return 'audio/wav';
    } else if (lower.endsWith('.mp3')) {
      return 'audio/mp3';
    } else if (lower.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    return 'audio/m4a';
  }
}

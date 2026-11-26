import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_icons.dart';
import '../../models/account_model.dart';
import '../../models/category_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/currency_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../services/chat_history_service.dart';
import '../../services/gemini_voice_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/action_button.dart';
import '../../widgets/animated_tab_bar.dart';
import '../../widgets/compact_option_picker_dialog.dart';
import 'voice_transaction_dialog.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionModel? editTransaction;
  final TransactionModel? copyFromTransaction;

  const TransactionFormScreen({
    super.key,
    this.editTransaction,
    this.copyFromTransaction,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  // Input mode: 'keyboard' or 'chat'
  String _inputMode = 'keyboard';

  // Transaction type: 'income', 'expense', 'transfer'
  String _type = 'expense';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(
    text: 'Rp 0',
  );
  final FocusNode _amountFocusNode = FocusNode();
  final TextEditingController _feeController = TextEditingController(
    text: 'Rp 0',
  );
  final TextEditingController _descController = TextEditingController();

  // Chat mode state
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<TransactionModel> _chatTransactions = [];
  List<ChatMessageModel> _chatMessages = [];
  bool _isLoadingChat = false;
  bool _isChatAiResponding = false;

  int _amount = 0;
  int _fee = 0;

  AccountModel? _selectedAccount;
  AccountModel? _selectedTargetAccount;
  CategoryModel? _selectedCategory;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    final tx = widget.editTransaction;
    final copyTx = widget.copyFromTransaction;

    if (tx != null) {
      _type = tx.type;
      _titleController.text = tx.title;
      _amount = tx.amount;
      _amountController.text = 'Rp ${CurrencyFormatter.formatNumber(_amount)}';
      _fee = tx.fee;
      _feeController.text = 'Rp ${CurrencyFormatter.formatNumber(_fee)}';
      _descController.text = tx.description ?? '';
      _selectedAccount = provider.findAccount(tx.accountId);
      _selectedTargetAccount = provider.findAccount(tx.targetAccountId);
      _selectedCategory = provider.getCategoryById(tx.category);
      _selectedDate = tx.dateTime;
      _selectedTime = TimeOfDay(
        hour: tx.dateTime.hour,
        minute: tx.dateTime.minute,
      );
      _imagePath = tx.img;
    } else if (copyTx != null) {
      _type = copyTx.type;
      _titleController.text = copyTx.title;
      _amount = copyTx.amount;
      _amountController.text = 'Rp ${CurrencyFormatter.formatNumber(_amount)}';
      _fee = copyTx.fee;
      _feeController.text = 'Rp ${CurrencyFormatter.formatNumber(_fee)}';
      _descController.text = copyTx.description ?? '';
      _selectedAccount = provider.findAccount(copyTx.accountId);
      _selectedTargetAccount = provider.findAccount(copyTx.targetAccountId);
      _selectedCategory = provider.getCategoryById(copyTx.category);
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    } else {
      if (provider.accounts.isNotEmpty) {
        _selectedAccount = provider.accounts.first;
        if (provider.accounts.length > 1) {
          _selectedTargetAccount = provider.accounts[1];
        }
      }
      final expenseCats = provider.getCategoriesByType('expense');
      if (expenseCats.isNotEmpty) {
        _selectedCategory = expenseCats.first;
      }
    }

    _loadChatHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputMode == 'keyboard') {
        _amountFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _feeController.dispose();
    _descController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final unformatted = CurrencyFormatter.unformat(val);
    _amount = unformatted;
    final formatted = 'Rp ${CurrencyFormatter.formatNumber(unformatted)}';
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onFeeChanged(String val) {
    final unformatted = CurrencyFormatter.unformat(val);
    _fee = unformatted;
    final formatted = 'Rp ${CurrencyFormatter.formatNumber(unformatted)}';
    _feeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  int get _typeIndex {
    if (_type == 'income') return 0;
    if (_type == 'expense') return 1;
    return 2;
  }

  void _onTypeTabChanged(int index) {
    const keys = ['income', 'expense', 'transfer'];
    final key = keys[index.clamp(0, 2)];
    setState(() {
      _type = key;
      final provider = context.read<TransactionProvider>();
      final cats = provider.getCategoriesByType(key);
      if (cats.isNotEmpty) {
        _selectedCategory = cats.first;
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
        final savedImage = await File(
          picked.path,
        ).copy('${appDir.path}/$fileName');
        setState(() {
          _imagePath = savedImage.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _showCategoryDialog() async {
    final provider = context.read<TransactionProvider>();
    final categories = provider.getCategoriesByType(_type);

    final selected = await showCompactOptionPickerDialog<CategoryModel>(
      context: context,
      options: categories
          .map(
            (cat) => CompactPickerOption<CategoryModel>(
              value: cat,
              label: cat.name,
              icon: AppIcons.getIcon(cat.icon),
              color: AppColors.parseHex(cat.color),
            ),
          )
          .toList(),
    );

    if (selected != null && mounted) {
      setState(() => _selectedCategory = selected);
    }
  }

  Future<void> _showAccountDialog({required bool isTarget}) async {
    final provider = context.read<TransactionProvider>();
    final accounts = provider.accounts;

    final selected = await showCompactOptionPickerDialog<AccountModel>(
      context: context,
      options: accounts
          .map(
            (acc) => CompactPickerOption<AccountModel>(
              value: acc,
              label: acc.name,
              icon: AppIcons.getIcon(acc.icon),
              color: AppColors.parseHex(acc.iconColor),
            ),
          )
          .toList(),
    );

    if (selected != null && mounted) {
      setState(() {
        if (isTarget) {
          _selectedTargetAccount = selected;
        } else {
          _selectedAccount = selected;
        }
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul transaksi harus diisi')),
      );
      return;
    }

    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah nominal harus lebih dari 0')),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih akun sumber')));
      return;
    }

    if (_type == 'transfer') {
      if (_selectedTargetAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih akun tujuan transfer')),
        );
        return;
      }
      if (_selectedAccount!.id == _selectedTargetAccount!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun asal dan tujuan tidak boleh sama'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<TransactionProvider>();
    final txDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final tx = TransactionModel(
      id: widget.editTransaction?.id ?? '',
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      amount: _amount,
      type: _type,
      accountId: _selectedAccount!.id,
      targetAccountId: _type == 'transfer' ? _selectedTargetAccount?.id : null,
      createdAt: txDateTime.millisecondsSinceEpoch.toString(),
      category: _type == 'transfer' ? '52841730' : _selectedCategory?.id,
      fee: _type == 'transfer' ? _fee : 0,
      img: _imagePath,
    );

    try {
      if (widget.editTransaction != null) {
        await provider.editTransaction(widget.editTransaction!.id, tx);
      } else {
        await provider.addTransaction(tx);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoadingChat = true);
    final msgs = await ChatHistoryService.instance.getMessages();
    if (mounted) {
      setState(() {
        _chatMessages = List.from(msgs);
        _isLoadingChat = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'HARI INI';
    } else if (msgDate == yesterday) {
      return 'KEMARIN';
    } else {
      return DateFormat('d MMMM yyyy').format(date).toUpperCase();
    }
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Riwayat Chat?'),
        content: const Text(
          'Semua pesan dalam riwayat chat ini akan dihapus. Transaksi yang sudah tersimpan di database tidak akan terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ChatHistoryService.instance.clearHistory();
      if (mounted) {
        await _loadChatHistory();
      }
    }
  }

  TransactionModel? _parseLocalChatTransaction(
    String raw,
    TransactionProvider provider,
  ) {
    final lower = raw.toLowerCase();
    final match = RegExp(r'\d+').firstMatch(lower);
    int parsedAmount = match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    if (parsedAmount > 0 && parsedAmount < 1000) {
      parsedAmount = parsedAmount * 1000;
    }
    if (parsedAmount <= 0) return null;

    CategoryModel? matchedCat;
    for (var cat in provider.categories) {
      if (lower.contains(cat.name.toLowerCase())) {
        matchedCat = cat;
        break;
      }
    }

    if (matchedCat == null) {
      if (lower.contains('makan') ||
          lower.contains('dinner') ||
          lower.contains('lunch') ||
          lower.contains('kue') ||
          lower.contains('sarapan')) {
        matchedCat = provider.categories.firstWhere(
          (c) => c.name.toLowerCase().contains('makan'),
          orElse: () => provider.categories.first,
        );
      } else if (lower.contains('kopi') || lower.contains('minum')) {
        matchedCat = provider.categories.firstWhere(
          (c) => c.name.toLowerCase().contains('minum'),
          orElse: () => provider.categories.first,
        );
      } else if (lower.contains('gaji') || lower.contains('salary')) {
        matchedCat = provider.categories.firstWhere(
          (c) => c.name.toLowerCase().contains('gaji'),
          orElse: () => provider.categories.first,
        );
      }
    }

    AccountModel? matchedAccount;
    for (var acc in provider.accounts) {
      if (lower.contains(acc.name.toLowerCase())) {
        matchedAccount = acc;
        break;
      }
    }
    matchedAccount ??=
        provider.accounts.isNotEmpty ? provider.accounts.first : null;
    if (matchedAccount == null) return null;

    final type = (matchedCat != null && matchedCat.type == 'income')
        ? 'income'
        : 'expense';

    return TransactionModel(
      id: const Uuid().v4(),
      title: raw,
      description: 'Input via Chat',
      amount: parsedAmount,
      type: type,
      accountId: matchedAccount.id,
      createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
      category: matchedCat?.id,
    );
  }

  Future<void> _handleWhatsAppChatSubmit() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isChatAiResponding) return;

    _chatInputController.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    final userMsg = ChatMessageModel(
      id: const Uuid().v4(),
      sender: 'user',
      message: text,
      timestamp: now,
      isVoice: false,
    );

    setState(() {
      _chatMessages.add(userMsg);
      _isChatAiResponding = true;
    });
    _scrollToBottom();

    final provider = context.read<TransactionProvider>();
    List<TransactionModel> createdTxs = [];
    String aiReplyText = '';

    try {
      final hasApiKey = await GeminiVoiceService.instance.hasApiKey();
      if (hasApiKey) {
        try {
          final parsed =
              await GeminiVoiceService.instance.parseTextToTransactions(
            textPrompt: text,
            accounts: provider.accounts,
            categories: provider.categories,
            currency: provider.currency,
          );
          createdTxs = parsed.map((p) => p.toTransactionModel()).toList();
        } catch (geminiErr) {
          debugPrint('Gemini text parse error: $geminiErr, falling back to local');
        }
      }

      if (createdTxs.isEmpty) {
        final localTx = _parseLocalChatTransaction(text, provider);
        if (localTx != null) {
          createdTxs = [localTx];
        }
      }

      if (createdTxs.isNotEmpty) {
        await provider.addTransactions(createdTxs);
        _chatTransactions.addAll(createdTxs);
        aiReplyText = createdTxs.length == 1
            ? 'Berhasil mencatat 1 transaksi:'
            : 'Berhasil mencatat ${createdTxs.length} transaksi:';
      } else {
        aiReplyText =
            'Maaf, saya belum dapat memahami transaksi dari pesan tersebut. Mohon sebutkan nominal dan keperluan transaksi (contoh: "makan siang 25rb bayar bca").';
      }
    } catch (e) {
      aiReplyText = 'Terjadi kesalahan saat memproses transaksi: $e';
    }

    final assistantMsg = ChatMessageModel(
      id: const Uuid().v4(),
      sender: 'assistant',
      message: aiReplyText,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isVoice: false,
      transactions: createdTxs,
    );

    if (mounted) {
      setState(() {
        _chatMessages.add(assistantMsg);
        _isChatAiResponding = false;
      });
      _scrollToBottom();
    }

    try {
      await ChatHistoryService.instance.addMessage(userMsg);
      await ChatHistoryService.instance.addMessage(assistantMsg);
    } catch (e) {
      debugPrint('Failed to save to ChatHistoryService: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();

    String appTitle = 'Expense';
    if (_type == 'income') appTitle = 'Income';
    if (_type == 'transfer') appTitle = 'Transfer';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Keyboard vs Chat Mode Switcher Pill (matching Screenshot 1 & 3)
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _inputMode = 'keyboard'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _inputMode == 'keyboard'
                            ? theme.cardColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _inputMode == 'keyboard'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.keyboard, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Keyboard',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _inputMode == 'keyboard'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _inputMode = 'chat');
                      _loadChatHistory();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _inputMode == 'chat'
                            ? theme.cardColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _inputMode == 'chat'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _inputMode == 'chat'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chat_bubble, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _inputMode == 'chat'
          ? _buildChatModeBody()
          : _buildKeyboardModeBody(theme, provider),
    );
  }

  // WhatsApp-styled Chat mode body
  Widget _buildChatModeBody() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TransactionProvider>();
    final currency = provider.currency;

    final bottomBarBg =
        isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5);
    final inputCardBg = isDark ? const Color(0xFF2A3942) : Colors.white;
    final inputTextColor =
        isDark ? Colors.white : const Color(0xFF111B21);

    return Container(
      child: Column(
        children: [

          // Chat Messages List
          Expanded(
            child: _isLoadingChat
                ? const Center(child: CircularProgressIndicator())
                : _chatMessages.isEmpty
                    ? _buildChatEmptyState(isDark)
                    : ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _chatMessages[index];
                          final prevMsg =
                              index > 0 ? _chatMessages[index - 1] : null;
                          final showDateHeader = prevMsg == null ||
                              !_isSameDay(msg.dateTime, prevMsg.dateTime);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateHeader)
                                _buildDatePill(msg.dateTime, isDark),
                              if (msg.sender == 'user')
                                _buildUserBubble(msg, isDark)
                              else
                                _buildAssistantBubble(
                                  msg,
                                  provider,
                                  currency,
                                  isDark,
                                ),
                            ],
                          );
                        },
                      ),
          ),

          if (_isChatAiResponding) _buildAiTypingIndicator(isDark),

          // WhatsApp Bottom Input Bar
          _buildWhatsAppInputBar(
            isDark: isDark,
            bottomBarBg: bottomBarBg,
            inputCardBg: inputCardBg,
            inputTextColor: inputTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill(DateTime date, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF182229)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          _formatDateHeader(date),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F),
          ),
        ),
      ),
    );
  }

  Widget _buildUserBubble(ChatMessageModel msg, bool isDark) {
    final bubbleBg =
        isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final textColor =
        isDark ? Colors.white : const Color(0xFF111B21);
    final timeColor =
        isDark ? Colors.white60 : const Color(0xFF667781);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(2),
            topRight: Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.isVoice) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF34B7F1)
                        : const Color(0xFF128C7E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Transaksi Suara',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF34B7F1)
                          : const Color(0xFF128C7E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
            ],
            Text(
              msg.message,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(msg.dateTime),
                  style: TextStyle(fontSize: 10, color: timeColor),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.done_all,
                  size: 15,
                  color: Color(0xFF53BDEB), // WhatsApp blue checkmarks
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(
    ChatMessageModel msg,
    TransactionProvider provider,
    CurrencyModel currency,
    bool isDark,
  ) {
    final bubbleBg = isDark ? const Color(0xFF202C33) : Colors.white;
    final textColor =
        isDark ? Colors.white : const Color(0xFF111B21);
    final timeColor =
        isDark ? Colors.white60 : const Color(0xFF667781);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Smart Money AI',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg.message,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.25,
              ),
            ),
            if (msg.transactions.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...msg.transactions.map((tx) {
                return _buildTransactionCard(
                  tx,
                  provider,
                  currency,
                  isDark,
                );
              }),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('HH:mm').format(msg.dateTime),
                style: TextStyle(fontSize: 10, color: timeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    TransactionModel tx,
    TransactionProvider provider,
    CurrencyModel currency,
    bool isDark,
  ) {
    final cat = provider.getCategoryById(tx.category);
    final account = provider.findAccount(tx.accountId);
    final catColor = cat != null
        ? AppColors.parseHex(cat.color)
        : AppColors.primary;
    final iconData = cat != null
        ? AppIcons.getIcon(cat.icon)
        : Icons.receipt_long;

    Color amountColor;
    String sign;
    if (tx.type == 'income') {
      amountColor = AppColors.income;
      sign = '+';
    } else if (tx.type == 'expense') {
      amountColor = AppColors.expense;
      sign = '-';
    } else {
      amountColor = AppColors.transfer;
      sign = '';
    }

    final cardBg =
        isDark ? const Color(0xFF111B21) : const Color(0xFFF7F8FA);
    final cardBorder =
        isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: catColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (account != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              account.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          DateFormat('dd MMM, HH:mm').format(tx.dateTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$sign${CurrencyFormatter.format(tx.amount, currency)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: amountColor,
                ),
              ),
            ],
          ),
          if (tx.description != null && tx.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tx.description!.trim(),
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202C33) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Smart Money AI sedang mengetik...',
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF182229)
                : const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : const Color(0xFFFFE082),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 24,
                color: isDark
                    ? const Color(0xFFF7C04A)
                    : const Color(0xFFE29500),
              ),
              const SizedBox(height: 8),
              Text(
                'Asisten Keuangan Pintar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF11181C),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pesan dan transaksi Anda diproses secara aman.\n\nKetik transaksi di bawah (misal: "makan siang 35rb di warteg pake gopay") atau tekan tombol mikrofon untuk berbicara.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.white70 : const Color(0xFF54656F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppInputBar({
    required bool isDark,
    required Color bottomBarBg,
    required Color inputCardBg,
    required Color inputTextColor,
  }) {
    final hasText = _chatInputController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: bottomBarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: inputCardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.sentiment_satisfied_alt_outlined,
                      size: 22,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _chatInputController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: inputTextColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ketik pesan transaksi...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                        onSubmitted: (_) => _handleWhatsAppChatSubmit(),
                      ),
                    ),
                    if (hasText)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                        onPressed: () {
                          setState(() => _chatInputController.clear());
                        },
                      )
                    else
                      const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: hasText
                  ? _handleWhatsAppChatSubmit
                  : () async {
                      await VoiceTransactionDialog.show(context: context);
                      if (mounted) {
                        await _loadChatHistory();
                      }
                    },
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A884), // WhatsApp signature green
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: hasText
                      ? const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keyboard form view matching Screenshot 3
  // Keyboard form view matching clean, compact vertical layout
  Widget _buildKeyboardModeBody(ThemeData theme, TransactionProvider provider) {
    final currency = provider.currency;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? theme.cardColor : Colors.white;
    final borderColor = isDark ? theme.dividerColor : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final labelColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Segmented Tab container: Income | Expense | Transfer
                AnimatedTabBar(
                  width: double.infinity,
                  height: 44,
                  activeIndex: _typeIndex,
                  onTabChanged: _onTypeTabChanged,
                  tabs: const [
                    TabItem(key: 'income', label: 'Income'),
                    TabItem(key: 'expense', label: 'Expense'),
                    TabItem(key: 'transfer', label: 'Transfer'),
                  ],
                ),
                const SizedBox(height: 14),

                // Date & Time Row (side by side, vertical labels)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildFormField(
                        label: 'Tanggal',
                        labelColor: labelColor,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: subtextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildFormField(
                        label: 'Waktu',
                        labelColor: labelColor,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (picked != null) {
                              setState(() => _selectedTime = picked);
                            }
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: subtextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Judul Transaksi
                _buildFormField(
                  label: 'Judul Transaksi',
                  labelColor: labelColor,
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Misal: Makan Siang, Belanja, Gaji...',
                      hintStyle: TextStyle(color: hintColor, fontSize: 13),
                      filled: true,
                      fillColor: cardBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Jumlah (Rp)
                _buildFormField(
                  label: 'Jumlah (${currency.symbol})',
                  labelColor: labelColor,
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onAmountChanged,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Kategori (if not transfer)
                if (_type != 'transfer') ...[
                  _buildFormField(
                    label: 'Kategori',
                    labelColor: labelColor,
                    child: GestureDetector(
                      onTap: _showCategoryDialog,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            if (_selectedCategory != null)
                              Icon(
                                AppIcons.getIcon(_selectedCategory!.icon),
                                color: AppColors.parseHex(
                                  _selectedCategory!.color,
                                ),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCategory?.name ?? 'Pilih Kategori',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: _selectedCategory != null
                                      ? textColor
                                      : hintColor,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: subtextColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],

                // Akun Sumber
                _buildFormField(
                  label: _type == 'transfer' ? 'Akun Sumber' : 'Akun',
                  labelColor: labelColor,
                  child: GestureDetector(
                    onTap: () => _showAccountDialog(isTarget: false),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          if (_selectedAccount != null)
                            Icon(
                              AppIcons.getIcon(_selectedAccount!.icon),
                              color: AppColors.parseHex(
                                _selectedAccount!.iconColor,
                              ),
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedAccount?.name ?? 'Pilih Akun',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedAccount != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${CurrencyFormatter.format(_selectedAccount!.balance, currency)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: subtextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Transfer specific rows
                if (_type == 'transfer') ...[
                  _buildFormField(
                    label: 'Akun Tujuan',
                    labelColor: labelColor,
                    child: GestureDetector(
                      onTap: () => _showAccountDialog(isTarget: true),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            if (_selectedTargetAccount != null)
                              Icon(
                                AppIcons.getIcon(_selectedTargetAccount!.icon),
                                color: AppColors.parseHex(
                                  _selectedTargetAccount!.iconColor,
                                ),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _selectedTargetAccount?.name ??
                                          'Pilih Akun Tujuan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedTargetAccount != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${CurrencyFormatter.format(_selectedTargetAccount!.balance, currency)})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtextColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: subtextColor,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildFormField(
                    label: 'Biaya Admin (${currency.symbol})',
                    labelColor: labelColor,
                    child: TextField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onFeeChanged,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],

                // Deskripsi & Lampiran Foto
                _buildFormField(
                  label: 'Deskripsi & Foto (Opsional)',
                  labelColor: labelColor,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descController,
                          maxLines: 3,
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Tambahkan catatan transaksi...',
                            hintStyle: TextStyle(
                              color: hintColor,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: cardBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          InkWell(
                            onTap: () => _pickImage(ImageSource.camera),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickImage(ImageSource.gallery),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Image preview if selected
                if (_imagePath != null && _imagePath!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        File(_imagePath!).existsSync()
                            ? Image.file(
                                File(_imagePath!),
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(() => _imagePath = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Sticky Bottom Action Bar pinned above the keyboard
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: borderColor.withOpacity(0.6), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ActionButton(
              title: widget.editTransaction != null
                  ? 'Update Transaksi'
                  : 'Tambah Transaksi',
              height: 48,
              borderRadius: 8,
              isLoading: _isLoading,
              onPress: _submit,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
    Color? labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: labelColor ?? const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

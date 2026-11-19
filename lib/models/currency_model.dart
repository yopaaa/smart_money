class CurrencyModel {
  final String currency;
  final String name;
  final String symbol;
  final String locale;

  const CurrencyModel({
    required this.currency,
    required this.name,
    required this.symbol,
    required this.locale,
  });

  Map<String, dynamic> toMap() {
    return {
      'currency': currency,
      'name': name,
      'symbol': symbol,
      'locale': locale,
    };
  }

  factory CurrencyModel.fromMap(Map<String, dynamic> map) {
    return CurrencyModel(
      currency: map['currency']?.toString() ?? 'IDR',
      name: map['name']?.toString() ?? 'Indonesian Rupiah',
      symbol: map['symbol']?.toString() ?? 'Rp',
      locale: map['locale']?.toString() ?? 'id-ID',
    );
  }

  static const CurrencyModel defaultCurrency = CurrencyModel(
    currency: 'IDR',
    name: 'Indonesian Rupiah',
    symbol: 'Rp',
    locale: 'id_ID',
  );
}

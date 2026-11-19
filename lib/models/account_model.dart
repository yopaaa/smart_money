class AccountModel {
  final String id;
  final String name;
  final int balance;
  final String type;
  final bool isLiability;
  final bool hidden;
  final String icon;
  final String iconColor;
  final String description;
  final bool isFavorite;

  AccountModel({
    required this.id,
    required this.name,
    this.balance = 0,
    required this.type,
    this.isLiability = false,
    this.hidden = false,
    this.icon = 'wallet',
    this.iconColor = '#4caf50',
    this.description = '',
    this.isFavorite = false,
  });

  AccountModel copyWith({
    String? id,
    String? name,
    int? balance,
    String? type,
    bool? isLiability,
    bool? hidden,
    String? icon,
    String? iconColor,
    String? description,
    bool? isFavorite,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      isLiability: isLiability ?? this.isLiability,
      hidden: hidden ?? this.hidden,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      description: description ?? this.description,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'type': type,
      'isLiability': isLiability ? 1 : 0,
      'hidden': hidden ? 1 : 0,
      'icon': icon,
      'iconColor': iconColor,
      'description': description,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      type: map['type']?.toString() ?? 'other',
      isLiability: (map['isLiability'] == 1 || map['isLiability'] == true),
      hidden: (map['hidden'] == 1 || map['hidden'] == true),
      icon: map['icon']?.toString() ?? 'wallet',
      iconColor: map['iconColor']?.toString() ?? '#4caf50',
      description: map['description']?.toString() ?? '',
      isFavorite: (map['isFavorite'] == 1 || map['isFavorite'] == true),
    );
  }
}

class AccountGroup {
  final String title;
  final String icon;
  final String color;
  final int balance;
  final List<AccountModel> accounts;

  AccountGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.balance,
    required this.accounts,
  });
}

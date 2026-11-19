class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String type; // 'income' | 'expense' | 'transfer' | 'none'

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? type,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      icon: map['icon']?.toString() ?? 'dots-horizontal',
      color: map['color']?.toString() ?? '#90a4ae',
      type: map['type']?.toString() ?? 'expense',
    );
  }
}

class CategoryStatModel {
  final String categoryId;
  final String categoryName;
  final int amount;
  final double percent;
  final CategoryModel category;

  CategoryStatModel({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.percent,
    required this.category,
  });
}

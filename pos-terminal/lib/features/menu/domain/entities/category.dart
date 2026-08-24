import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  /// Kategoriya rasmi (admin panelda o'rnatiladi). Nisbiy yoki to'liq URL.
  final String? imageUrl;

  const Category({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, name, sortOrder, imageUrl];
}

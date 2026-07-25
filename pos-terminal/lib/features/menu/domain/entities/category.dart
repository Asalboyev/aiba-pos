import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final int sortOrder;

  const Category({required this.id, required this.name, this.sortOrder = 0});

  @override
  List<Object?> get props => [id, name, sortOrder];
}

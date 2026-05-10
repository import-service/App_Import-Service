import 'package:equatable/equatable.dart';

/// Данные для добавления авто в список (без привязки к JSON API).
final class NewCarListInput extends Equatable {
  const NewCarListInput({
    required this.buyerFullName,
    required this.brand,
    required this.model,
    required this.vin,
  });

  final String buyerFullName;
  final String brand;
  final String model;
  final String vin;

  String get displayModelLine {
    final b = brand.trim();
    final m = model.trim();
    if (b.isEmpty && m.isEmpty) return '—';
    if (b.isEmpty) return m;
    if (m.isEmpty) return b;
    return '$b $m';
  }

  @override
  List<Object?> get props => [buyerFullName, brand, model, vin];
}

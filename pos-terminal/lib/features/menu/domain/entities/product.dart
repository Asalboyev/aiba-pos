import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String? categoryId;
  final String name;
  final String? sku;
  final num price;
  final String? mxikCode;
  final String? packageCode;
  final num vatPercent;
  final String unit;
  final String? imageUrl;
  final bool isActive;
  /// True → DataMatrix markirovka har dona uchun majburiy (alkogol, sigareta,
  /// dori). Kassir mahsulotni savatga qo'shishda skanerlashi kerak, aks holda
  /// backend 400 xato beradi va chek yaratilmaydi.
  final bool markingRequired;

  /// True → mahsulot ombor'da hisoblanadi (Cola, alkogol shishalar).
  /// False → cheksiz (palov, choy — tayyor ovqat).
  final bool trackStock;
  /// Hozirgi qoldiq (agar trackStock=true bo'lsa).
  final num stockQty;
  /// Ogohlantirish chegarasi — qoldiq shundan kam bo'lsa turli chip.
  final num lowStockThreshold;

  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    this.sku,
    required this.price,
    this.mxikCode,
    this.packageCode,
    this.vatPercent = 12,
    this.unit = 'dona',
    this.imageUrl,
    this.isActive = true,
    this.markingRequired = false,
    this.trackStock = false,
    this.stockQty = 0,
    this.lowStockThreshold = 10,
  });

  /// Kilolab (tarozida) sotiladi — admin panelda "Birlik" maydoniga
  /// "kg" yozilgan mahsulot. Narx 1 kg uchun kiritiladi; kassada bosilganda
  /// gramm so'raladi.
  bool get soldByWeight {
    final u = unit.trim().toLowerCase();
    return u == 'kg' || u == 'кг' || u == 'kilogramm' || u == 'килограмм';
  }

  /// Sotib bo'lmaydi (ombor tugagan).
  bool get outOfStock => trackStock && stockQty <= 0;
  /// Kam qoldi (turli chip).
  bool get lowStock => trackStock && stockQty > 0 && stockQty <= lowStockThreshold;

  @override
  List<Object?> get props => [
        id,
        categoryId,
        name,
        sku,
        price,
        mxikCode,
        packageCode,
        vatPercent,
        unit,
        imageUrl,
        isActive,
        markingRequired,
        trackStock,
        stockQty,
        lowStockThreshold,
      ];
}

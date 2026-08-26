import 'package:equatable/equatable.dart';

class RestaurantInfo extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? legalName;
  final String? inn;
  final String? address;
  // --- Chek sozlamalari (adminkadan boshqariladi) ---
  final String? receiptLogoUrl;
  final String? receiptHeader;
  final String? receiptFooter;
  final String? receiptPhone;
  final bool receiptShowQr;
  /// Naqd chek fiskal FAQAT so'ralganda (F12)? false = naqd ham darhol
  /// fiskal bo'lib QR bilan chiqadi (standart, eski xatti-harakat).
  final bool cashFiscalOnDemand;
  final bool receiptShowMxik;
  final int receiptPaperWidth; // 58 yoki 80 (mm)
  /// Restoran fiskal rejimi (mock / epos / epos_terminal). epos_terminal
  /// bo'lsa internet uzilganda chek lokal Communicator orqali fiskalizatsiya
  /// qilinadi (oflayn fiskal).
  final String? fiscalProvider;

  const RestaurantInfo({
    required this.id,
    required this.name,
    required this.code,
    this.legalName,
    this.inn,
    this.address,
    this.receiptLogoUrl,
    this.receiptHeader,
    this.receiptFooter,
    this.receiptPhone,
    this.receiptShowQr = true,
    this.cashFiscalOnDemand = false,
    this.receiptShowMxik = true,
    this.receiptPaperWidth = 80,
    this.fiscalProvider,
  });

  /// Oflayn fiskalga ruxsat: chek kassadagi Communicator orqali yuboriladi.
  bool get fiscalViaTerminal => fiscalProvider == 'epos_terminal';

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        legalName,
        inn,
        address,
        receiptLogoUrl,
        receiptHeader,
        receiptFooter,
        receiptPhone,
        receiptShowQr,
        receiptShowMxik,
        receiptPaperWidth,
        fiscalProvider,
      ];
}

class TerminalInfo extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? fiscalTerminalId;

  const TerminalInfo({
    required this.id,
    required this.name,
    required this.code,
    this.fiscalTerminalId,
  });

  @override
  List<Object?> get props => [id, name, code, fiscalTerminalId];
}

class StaffInfo extends Equatable {
  final String id;
  final String name;
  final String role;

  const StaffInfo({required this.id, required this.name, required this.role});

  @override
  List<Object?> get props => [id, name, role];
}

/// A successful terminal+staff login. Persisted between launches so the POS
/// keeps working offline after the first online login.
class AuthSession extends Equatable {
  final String accessToken;
  final RestaurantInfo restaurant;
  final TerminalInfo terminal;
  final StaffInfo staff;
  final String? shiftId;

  const AuthSession({
    required this.accessToken,
    required this.restaurant,
    required this.terminal,
    required this.staff,
    this.shiftId,
  });

  AuthSession copyWith({String? shiftId}) => AuthSession(
        accessToken: accessToken,
        restaurant: restaurant,
        terminal: terminal,
        staff: staff,
        shiftId: shiftId ?? this.shiftId,
      );

  @override
  List<Object?> get props => [accessToken, restaurant, terminal, staff, shiftId];
}

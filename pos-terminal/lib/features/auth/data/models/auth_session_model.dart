import '../../domain/entities/auth_session.dart';

/// Maps the `/auth/login` response (and persisted JSON) to [AuthSession].
class AuthSessionModel {
  static AuthSession fromLoginJson(Map<String, dynamic> json) {
    final r = (json['restaurant'] as Map?)?.cast<String, dynamic>() ?? const {};
    final t = (json['terminal'] as Map?)?.cast<String, dynamic>() ?? const {};
    final s = (json['staff'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AuthSession(
      accessToken: (json['access_token'] ?? '').toString(),
      restaurant: RestaurantInfo(
        id: (r['id'] ?? '').toString(),
        name: (r['name'] ?? '').toString(),
        code: (r['code'] ?? '').toString(),
        legalName: r['legal_name']?.toString(),
        inn: r['inn']?.toString(),
        address: r['address']?.toString(),
        receiptLogoUrl: r['receipt_logo_url']?.toString(),
        receiptHeader: r['receipt_header']?.toString(),
        receiptFooter: r['receipt_footer']?.toString(),
        receiptPhone: r['receipt_phone']?.toString(),
        receiptShowQr: r['receipt_show_qr'] != false,
        cashFiscalOnDemand: r['cash_fiscal_on_demand'] == true,
        receiptShowMxik: r['receipt_show_mxik'] != false,
        receiptPaperWidth: (r['receipt_paper_width'] is int)
            ? r['receipt_paper_width'] as int
            : int.tryParse('${r['receipt_paper_width'] ?? 80}') ?? 80,
        fiscalProvider: r['fiscal_provider']?.toString(),
      ),
      terminal: TerminalInfo(
        id: (t['id'] ?? '').toString(),
        name: (t['name'] ?? '').toString(),
        code: (t['code'] ?? '').toString(),
        fiscalTerminalId: t['fiscal_terminal_id']?.toString(),
      ),
      staff: StaffInfo(
        id: (s['id'] ?? '').toString(),
        // Backend may send full_name or name; prefer full_name.
        name: (s['full_name'] ?? s['name'] ?? '').toString(),
        role: (s['role'] ?? '').toString(),
      ),
      shiftId: json['shift_id']?.toString(),
    );
  }

  /// Serialize for local (prefs) persistence — token is stored separately/secure.
  static Map<String, dynamic> toPersistedJson(AuthSession s) => {
        'restaurant': {
          'id': s.restaurant.id,
          'name': s.restaurant.name,
          'code': s.restaurant.code,
          'legal_name': s.restaurant.legalName,
          'inn': s.restaurant.inn,
          'address': s.restaurant.address,
          'receipt_logo_url': s.restaurant.receiptLogoUrl,
          'receipt_header': s.restaurant.receiptHeader,
          'receipt_footer': s.restaurant.receiptFooter,
          'receipt_phone': s.restaurant.receiptPhone,
          'receipt_show_qr': s.restaurant.receiptShowQr,
          'cash_fiscal_on_demand': s.restaurant.cashFiscalOnDemand,
          'receipt_show_mxik': s.restaurant.receiptShowMxik,
          'receipt_paper_width': s.restaurant.receiptPaperWidth,
        },
        'terminal': {
          'id': s.terminal.id,
          'name': s.terminal.name,
          'code': s.terminal.code,
          'fiscal_terminal_id': s.terminal.fiscalTerminalId,
        },
        'staff': {
          'id': s.staff.id,
          'full_name': s.staff.name,
          'role': s.staff.role,
        },
        'shift_id': s.shiftId,
      };

  /// Restore from persisted JSON, supplying the securely-stored token.
  static AuthSession fromPersistedJson(
    Map<String, dynamic> json,
    String token,
  ) {
    final withToken = {...json, 'access_token': token};
    return fromLoginJson(withToken);
  }
}

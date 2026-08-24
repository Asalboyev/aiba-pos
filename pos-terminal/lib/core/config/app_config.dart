import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted, user-editable configuration for the terminal.
///
/// Non-secret values (base URL, terminal code, printer host/port) live in
/// [SharedPreferences]. The JWT access token lives in [FlutterSecureStorage].
class AppConfig {
  AppConfig(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kBaseUrl = 'base_url';
  static const _kTerminalCode = 'terminal_code';
  static const _kPrinterHost = 'printer_host';
  static const _kPrinterPort = 'printer_port';
  static const _kPrinterUsb = 'printer_usb';
  static const _kPrinterName = 'printer_name';
  static const _kCommunicatorUrl = 'communicator_url';
  static const _kOrderSeqDate = 'order_seq_date';
  static const _kOrderSeq = 'order_seq';
  static const _kSetupDone = 'setup_done';
  static const _kToken = 'access_token';

  // AIBA Nex backend — the terminal API lives under /api/v2/pos-terminal/*
  // (paths appended by the datasources). Dev: http://<mac-ip>:18001
  static const defaultBaseUrl = 'https://next.aiba.uz';
  static const defaultPrinterPort = 9100;

  // E-POS Communicator shu kassa kompyuterida ishlaydi (fiskal modul USB'da).
  // Dokumentatsiya bo'yicha prod manzili doim localhost:8347.
  static const defaultCommunicatorUrl = 'http://127.0.0.1:8347/uzpos';

  String get baseUrl => _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
  Future<void> setBaseUrl(String value) => _prefs.setString(_kBaseUrl, value.trim());

  String get terminalCode => _prefs.getString(_kTerminalCode) ?? '';
  Future<void> setTerminalCode(String value) =>
      _prefs.setString(_kTerminalCode, value.trim());

  /// Terminal bir marta muvaffaqiyatli kirgan — sozlash tugagan.
  /// Shundan keyin login ekranidagi yashirin "000" kodi ISHLAMAYDI: sozlamalar
  /// faqat birinchi o'rnatishda bir marta kiritiladi. Kirish muvaffaqiyatsiz
  /// bo'lsa bayroq qo'yilmaydi — noto'g'ri sozlamani tuzatish mumkin.
  bool get setupDone => _prefs.getBool(_kSetupDone) ?? false;
  Future<void> markSetupDone() => _prefs.setBool(_kSetupDone, true);

  String? get printerHost {
    final v = _prefs.getString(_kPrinterHost);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> setPrinterHost(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(_kPrinterHost);
    } else {
      await _prefs.setString(_kPrinterHost, value.trim());
    }
  }

  int get printerPort => _prefs.getInt(_kPrinterPort) ?? defaultPrinterPort;
  Future<void> setPrinterPort(int value) => _prefs.setInt(_kPrinterPort, value);

  /// When true the receipt is sent to a locally attached USB ESC/POS printer
  /// instead of a network one (takes precedence over [printerHost]).
  bool get printerUsb => _prefs.getBool(_kPrinterUsb) ?? false;
  Future<void> setPrinterUsb(bool value) => _prefs.setBool(_kPrinterUsb, value);

  /// Windows USB chop etish uchun o'rnatilgan printer nomi. Bo'sh bo'lsa —
  /// tizimning standart printeri ishlatiladi. (macOS'da kerak emas.)
  String get printerName {
    final v = _prefs.getString(_kPrinterName);
    return (v == null) ? '' : v.trim();
  }
  Future<void> setPrinterName(String value) =>
      _prefs.setString(_kPrinterName, value.trim());

  /// Kassadagi E-POS Communicator manzili (fiskal ko'prik). Bo'sh qoldirilsa
  /// standart localhost ishlatiladi.
  String get communicatorUrl {
    final v = _prefs.getString(_kCommunicatorUrl)?.trim();
    return (v == null || v.isEmpty) ? defaultCommunicatorUrl : v;
  }

  Future<void> setCommunicatorUrl(String value) =>
      _prefs.setString(_kCommunicatorUrl, value.trim());

  /// Next daily order number, generated locally so every printed receipt has
  /// one even offline. Resets each day; prefixed with the terminal code so
  /// numbers don't collide across terminals (e.g. "T1-7").
  Future<String> nextOrderNumber() async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';
    var seq = 1;
    if (_prefs.getString(_kOrderSeqDate) == dateKey) {
      seq = (_prefs.getInt(_kOrderSeq) ?? 0) + 1;
    }
    await _prefs.setString(_kOrderSeqDate, dateKey);
    await _prefs.setInt(_kOrderSeq, seq);
    final code = terminalCode;
    return code.isEmpty ? '$seq' : '$code-$seq';
  }

  // --- Secure token ---
  Future<String?> getToken() => _secure.read(key: _kToken);
  Future<void> setToken(String? token) async {
    if (token == null) {
      await _secure.delete(key: _kToken);
    } else {
      await _secure.write(key: _kToken, value: token);
    }
  }
}

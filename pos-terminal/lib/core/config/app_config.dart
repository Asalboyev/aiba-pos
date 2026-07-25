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
  static const _kOrderSeqDate = 'order_seq_date';
  static const _kOrderSeq = 'order_seq';
  static const _kToken = 'access_token';

  // AIBA Nex backend — the terminal API lives under /api/v2/pos-terminal/*
  // (paths appended by the datasources). Dev: http://<mac-ip>:18001
  static const defaultBaseUrl = 'https://next.aiba.uz';
  static const defaultPrinterPort = 9100;

  String get baseUrl => _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
  Future<void> setBaseUrl(String value) => _prefs.setString(_kBaseUrl, value.trim());

  String get terminalCode => _prefs.getString(_kTerminalCode) ?? '';
  Future<void> setTerminalCode(String value) =>
      _prefs.setString(_kTerminalCode, value.trim());

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

// NetworkPrinter (esc_pos_printer) is built on the older `esc_pos_utils`
// package, so its PaperSize/CapabilityProfile come from there. The receipt
// byte stream itself is produced by ReceiptBuilder using esc_pos_utils_plus —
// the output is a plain List<int>, so the two packages interoperate cleanly.
import 'dart:io';

import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart' as legacy;
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../domain/receipt_data.dart';
import 'receipt_builder.dart';

enum PrintOutcome { printed, noPrinter, failed }

class PrintReport {
  final PrintOutcome outcome;
  final String message;
  const PrintReport(this.outcome, this.message);
}

/// Sends receipts to an ESC/POS printer — network (host:port) or local USB.
/// Designed to be no-printer-safe: if nothing is configured (or the printer
/// is unreachable) it returns a non-fatal report so checkout always completes.
class PrinterService {
  PrinterService(this._config);
  final AppConfig _config;

  // macOS exposes no /dev node for USB printers; the CUPS usb backend is the
  // supported raw byte path (raw queues were removed from macOS CUPS, so we
  // invoke the backend directly: no args = discovery, with args = print job).
  static const _macUsbBackend = '/usr/libexec/cups/backend/usb';

  Future<PrintReport> printReceipt(ReceiptData data) async {
    debugPrint('[PrinterService] printing: restaurant="${data.restaurantName}" '
        'payments=${data.payments.map((p) => p.method.code).join(',')}');
    if (_config.printerUsb) {
      return _sendUsb(await ReceiptBuilder.build(data));
    }
    final host = _config.printerHost;
    if (host == null || host.isEmpty) {
      // No printer configured — log a preview and continue.
      debugPrint('[PrinterService] No printer configured. Receipt preview:\n'
          '${_previewText(data)}');
      return const PrintReport(
        PrintOutcome.noPrinter,
        'Printer sozlanmagan — chek faqat ekranda',
      );
    }
    return _sendNetwork(host, await ReceiptBuilder.build(data));
  }

  /// Prints a short hardware test ticket through the configured transport.
  Future<PrintReport> printTest() async {
    final bytes = await ReceiptBuilder.buildTest();
    if (_config.printerUsb) return _sendUsb(bytes);
    final host = _config.printerHost;
    if (host == null || host.isEmpty) {
      return const PrintReport(
        PrintOutcome.noPrinter,
        'Printer sozlanmagan — USB yoki IP kiriting',
      );
    }
    return _sendNetwork(host, bytes);
  }

  Future<PrintReport> _sendNetwork(String host, List<int> bytes) async {
    try {
      final profile = await legacy.CapabilityProfile.load();
      final printer = NetworkPrinter(legacy.PaperSize.mm80, profile);
      final res = await printer.connect(host, port: _config.printerPort);
      if (res != PosPrintResult.success) {
        return PrintReport(PrintOutcome.failed, 'Printer: ${res.msg}');
      }
      printer.rawBytes(bytes);
      printer.disconnect(delayMs: 200);
      return const PrintReport(PrintOutcome.printed, 'Chek chop etildi');
    } catch (e) {
      debugPrint('[PrinterService] print failed: $e');
      return PrintReport(PrintOutcome.failed, 'Chop etish xatosi: $e');
    }
  }

  Future<PrintReport> _sendUsb(List<int> bytes) async {
    if (!Platform.isMacOS) {
      return const PrintReport(
        PrintOutcome.failed,
        'USB chop etish hozircha faqat macOS-da qo\'llanadi',
      );
    }
    try {
      final uri = await _discoverUsbPrinter();
      if (uri == null) {
        return const PrintReport(
          PrintOutcome.failed,
          'USB printer topilmadi — kabel va quvvatni tekshiring',
        );
      }
      final tmp = File(
          '${Directory.systemTemp.path}/aiba-receipt-${DateTime.now().microsecondsSinceEpoch}.bin');
      await tmp.writeAsBytes(bytes, flush: true);
      try {
        final res = await Process.run(
          _macUsbBackend,
          ['1', Platform.environment['USER'] ?? 'pos', 'aiba-receipt', '1', '', tmp.path],
          environment: {'DEVICE_URI': uri},
        ).timeout(const Duration(seconds: 30));
        if (res.exitCode != 0) {
          debugPrint('[PrinterService] usb backend stderr: ${res.stderr}');
          return PrintReport(
              PrintOutcome.failed, 'USB printer xatosi (exit ${res.exitCode})');
        }
        return const PrintReport(PrintOutcome.printed, 'Chek chop etildi (USB)');
      } finally {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PrinterService] USB print failed: $e');
      return PrintReport(PrintOutcome.failed, 'Chop etish xatosi: $e');
    }
  }

  Future<String?> _discoverUsbPrinter() async {
    final res = await Process.run(_macUsbBackend, const [])
        .timeout(const Duration(seconds: 10));
    final m = RegExp(r'direct (usb://\S+)').firstMatch(res.stdout.toString());
    return m?.group(1);
  }

  String _previewText(ReceiptData d) {
    final b = StringBuffer()
      ..writeln(d.restaurantName)
      ..writeln('JAMI: ${d.total}');
    for (final i in d.items) {
      b.writeln('${i.qty} x ${i.name} = ${i.lineTotal}');
    }
    if (d.fiscal?.qrUrl != null) b.writeln('QR: ${d.fiscal!.qrUrl}');
    return b.toString();
  }
}

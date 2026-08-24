// NetworkPrinter (esc_pos_printer) is built on the older `esc_pos_utils`
// package, so its PaperSize/CapabilityProfile come from there. The receipt
// byte stream itself is produced by ReceiptBuilder using esc_pos_utils_plus —
// the output is a plain List<int>, so the two packages interoperate cleanly.
import 'dart:convert';
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
    final bytes = await ReceiptBuilder.build(data);
    if (_config.printerUsb) return _sendLocal(bytes);
    final host = _config.printerHost;
    if (host != null && host.isNotEmpty) return _sendNetwork(host, bytes);
    // Hech narsa sozlanmagan — Windows/macOS'da ulangan USB printerni
    // avtomatik urinib ko'ramiz (nol-sozlama). Topilmasa chek ekranda qoladi,
    // checkout baribir yakunlanadi.
    if (Platform.isWindows || Platform.isMacOS) {
      final report = await _sendLocal(bytes);
      if (report.outcome == PrintOutcome.printed) return report;
      debugPrint('[PrinterService] auto USB print failed '
          '(${report.message}). Receipt preview:\n${_previewText(data)}');
      return PrintReport(PrintOutcome.noPrinter, report.message);
    }
    debugPrint('[PrinterService] No printer configured. Receipt preview:\n'
        '${_previewText(data)}');
    return const PrintReport(
      PrintOutcome.noPrinter,
      'Printer sozlanmagan — chek faqat ekranda',
    );
  }

  /// QR to'lov talonini bosадi (fiskal emas) — WLCM checkout QR'i.
  Future<PrintReport> printQrSlip({
    required String url,
    required num amount,
    int paperWidth = 80,
  }) async {
    final bytes = await ReceiptBuilder.buildQrSlip(
        url: url, amount: amount, paperWidth: paperWidth);
    if (_config.printerUsb) return _sendLocal(bytes);
    final host = _config.printerHost;
    if (host != null && host.isNotEmpty) return _sendNetwork(host, bytes);
    if (Platform.isWindows || Platform.isMacOS) return _sendLocal(bytes);
    return const PrintReport(
      PrintOutcome.noPrinter,
      'Printer sozlanmagan — QR faqat ekranda',
    );
  }

  /// Prints a short hardware test ticket through the configured transport.
  Future<PrintReport> printTest() async {
    final bytes = await ReceiptBuilder.buildTest(paperWidth: 80);
    if (_config.printerUsb) return _sendLocal(bytes);
    final host = _config.printerHost;
    if (host != null && host.isNotEmpty) return _sendNetwork(host, bytes);
    // Sozlanmagan bo'lsa ham lokal USB printerga urinamiz — kassir hech
    // narsa kiritmasdan test chekini olishi kerak.
    if (Platform.isWindows || Platform.isMacOS) return _sendLocal(bytes);
    return const PrintReport(
      PrintOutcome.noPrinter,
      'Printer sozlanmagan — USB yoki IP kiriting',
    );
  }

  /// Lokal (USB) chop etish — OS bo'yicha yo'naltiradi: macOS → CUPS usb
  /// backend, Windows → print spooler RAW (winspool). Linux hozircha yo'q.
  Future<PrintReport> _sendLocal(List<int> bytes) {
    if (Platform.isMacOS) return _sendUsb(bytes);
    if (Platform.isWindows) return _sendWindows(bytes);
    return Future.value(const PrintReport(
      PrintOutcome.failed,
      'USB chop etish faqat Windows va macOS-da qo\'llanadi. IP printer ishlating.',
    ));
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

  /// Windows RAW chop etish — print spooler orqali (winspool.drv), ESC/POS
  /// baytlarini o'zgartirmasdan yuboradi. Printer nomi Sozlamalardan olinadi;
  /// bo'sh bo'lsa skript o'zi chek-printerni avtomatik aniqlaydi (virtual
  /// printerlar tashlanadi, termal/POS nomlilar afzal). PowerShell'ga kichik
  /// C# (RawPrinterHelper) yuklaymiz — qo'shimcha plagin kerak emas.
  Future<PrintReport> _sendWindows(List<int> bytes) async {
    try {
      final tmp = Directory.systemTemp.path;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final binPath = '$tmp\\aiba-receipt-$stamp.bin';
      final ps1Path = '$tmp\\aiba-print-$stamp.ps1';
      await File(binPath).writeAsBytes(bytes, flush: true);
      // .ps1 UTF-8 BOM bilan yoziladi: BOM'siz PowerShell 5.1 faylni ANSI
      // deb o'qiydi va har qanday non-ASCII belgi skriptni buzadi
      // (TerminatorExpectedAtEndOfString).
      await File(ps1Path).writeAsBytes(
        [0xEF, 0xBB, 0xBF, ...utf8.encode(_winPrintScript)],
        flush: true,
      );
      try {
        final res = await Process.run(
          'powershell',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1Path],
          environment: {
            'AIBA_BINFILE': binPath,
            'AIBA_PRINTER': _config.printerName, // bo'sh = avtomatik aniqlash
          },
        ).timeout(const Duration(seconds: 60));
        if (res.exitCode != 0) {
          final errText = res.stderr.toString().trim();
          final outText = res.stdout.toString().trim();
          debugPrint('[PrinterService] windows print failed:\n'
              'stdout: $outText\nstderr: $errText');
          // Skript xatoni stderr'ga bitta toza qator qilib yozadi (Fail
          // funksiyasi) — birinchi bo'sh bo'lmagan qatorni ko'rsatamiz.
          final src = errText.isNotEmpty ? errText : outText;
          final lines =
              src.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
          final msg = lines.isEmpty ? 'noma\'lum xato' : lines.first;
          return PrintReport(PrintOutcome.failed, 'Printerga yuborilmadi: $msg');
        }
        return const PrintReport(PrintOutcome.printed, 'Chek chop etildi');
      } finally {
        try {
          await File(binPath).delete();
        } catch (_) {}
        try {
          await File(ps1Path).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PrinterService] windows print error: $e');
      return PrintReport(PrintOutcome.failed, 'Chop etish xatosi: $e');
    }
  }

  // PowerShell RAW-print skripti. C# RawPrinterHelper winspool.drv orqali
  // StartDocPrinter(RAW) + WritePrinter qiladi — ESC/POS baytlari xom holicha
  // ketadi (drayver rasterlamaydi). Printer nomi/bin fayli env orqali beriladi.
  static const String _winPrintScript = r'''
$ErrorActionPreference = 'Stop'
# Xatolarni bitta toza qator qilib stderr'ga yozamiz - Dart tomonda shu
# qator kassirga ko'rsatiladi (PowerShell'ning shovqinli formati o'rniga).
function Fail([string]$msg) { [Console]::Error.WriteLine($msg); exit 1 }
$code = @'
using System;
using System.Runtime.InteropServices;
public class AibaRawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint="OpenPrinterA", SetLastError=true, CharSet=CharSet.Ansi)]
  public static extern bool OpenPrinter(string src, out IntPtr h, IntPtr pd);
  [DllImport("winspool.Drv", EntryPoint="ClosePrinter")]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.Drv", EntryPoint="StartDocPrinterA", CharSet=CharSet.Ansi)]
  public static extern bool StartDocPrinter(IntPtr h, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.Drv", EntryPoint="EndDocPrinter")]
  public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.Drv", EntryPoint="StartPagePrinter")]
  public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.Drv", EntryPoint="EndPagePrinter")]
  public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.Drv", EntryPoint="WritePrinter")]
  public static extern bool WritePrinter(IntPtr h, IntPtr buf, int count, out int written);
  public static void Send(string printer, byte[] bytes) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero))
      throw new Exception("Printer ochilmadi: " + printer +
        " (Win32 kod " + Marshal.GetLastWin32Error() + ")");
    try {
      var di = new DOCINFOA(); di.pDocName = "AIBA POS"; di.pDataType = "RAW";
      if (!StartDocPrinter(h, 1, di)) throw new Exception("StartDocPrinter xato");
      try {
        StartPagePrinter(h);
        IntPtr p = Marshal.AllocCoTaskMem(bytes.Length);
        try {
          Marshal.Copy(bytes, 0, p, bytes.Length);
          int w;
          if (!WritePrinter(h, p, bytes.Length, out w)) throw new Exception("WritePrinter xato");
        } finally { Marshal.FreeCoTaskMem(p); }
        EndPagePrinter(h);
      } finally { EndDocPrinter(h); }
    } finally { ClosePrinter(h); }
  }
}
'@
try { Add-Type -TypeDefinition $code -Language CSharp } catch { Fail ("PowerShell Add-Type xatosi: " + $_.Exception.Message) }
$printer = $env:AIBA_PRINTER
if (-not [string]::IsNullOrWhiteSpace($printer)) {
  # Sozlamalarda kiritilgan nom aynan topilmasa: avval qisman moslik
  # ("Xprint" -> "Xprinter XP-58IIH"), bo'lmasa avtomatik aniqlashga o'tamiz.
  $names = @(Get-CimInstance -Class Win32_Printer -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
  if ($names -notcontains $printer) {
    $m = @($names | Where-Object { $_ -like ('*' + $printer + '*') })
    if ($m.Count -ge 1) {
      Write-Output "AIBA: '$printer' qisman mos keldi: $($m[0])"
      $printer = $m[0]
    } else {
      Write-Output "AIBA: '$printer' nomli printer yo'q, avtomatik aniqlashga o'tildi"
      $printer = ''
    }
  }
}
if ([string]::IsNullOrWhiteSpace($printer)) {
  # Avtomatik aniqlash: virtual printerlarni tashlab, chek (termal ESC/POS)
  # printerga o'xshaganini tanlaymiz. Tartib: nom/drayver kalit so'zi ->
  # USB portdagi printer -> standart printer -> yagona real printer.
  # USB portlar: USB001... yoki ESDPRT001 (Xprinter va o'xshash drayverlar).
  $all = @(Get-CimInstance -Class Win32_Printer -ErrorAction SilentlyContinue)
  $virtual = 'Print to PDF|XPS|OneNote|Fax|AnyDesk|PDF24|Foxit|Adobe PDF'
  $real = @($all | Where-Object { ($_.Name + ' ' + $_.DriverName) -notmatch $virtual })
  $kw = 'POS|THERM|RECEIPT|CHEK|AIBA|XPRINTER|XP-|RONGTA|RP-|TM-|GP-|GOOJPRT|SEWOO|BIXOLON|CITIZEN|ZYWELL|HOIN|OCPP|GENERIC|(^|[^0-9])(58|80)([^0-9]|$)'
  $usbPort = '^(USB|ESDPRT|POS)'
  $cand = @($real | Where-Object { ($_.Name + ' ' + $_.DriverName) -match $kw } |
    Sort-Object -Property @{Expression={-not $_.WorkOffline};Descending=$true},
                          @{Expression={$_.PortName -match $usbPort};Descending=$true},
                          @{Expression={$_.Default};Descending=$true})
  if ($cand.Count -eq 0) {
    $cand = @($real | Where-Object { $_.PortName -match $usbPort } |
      Sort-Object -Property @{Expression={-not $_.WorkOffline};Descending=$true})
  }
  if ($cand.Count -eq 0) { $cand = @($real | Where-Object { $_.Default }) }
  if ($cand.Count -eq 0 -and $real.Count -eq 1) { $cand = $real }
  if ($cand.Count -gt 0) {
    $printer = $cand[0].Name
    Write-Output "AIBA: printer avtomatik tanlandi: $printer"
  } else {
    if ($real.Count -gt 1) {
      Fail ("Qaysi biri chek printer ekani aniqlanmadi. Sozlamalarda printer nomini kiriting. Printerlar: " + (($real | ForEach-Object { $_.Name }) -join '; '))
    }
    # Windows'da printer o'rnatilmagan. USB printer porti ko'rinsa,
    # Windows'ning ichki 'Generic / Text Only' drayveri bilan avtomatik
    # o'rnatamiz - RAW rejimda ESC/POS baytlari baribir o'zgarmasdan o'tadi.
    $port = @(Get-PrinterPort -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^(USB\d|ESDPRT)' }) | Select-Object -First 1
    if ($port -eq $null) {
      Fail "Chek printer topilmadi: USB kabel va printer quvvatini tekshiring."
    }
    try {
      if (-not (Get-PrinterDriver -Name 'Generic / Text Only' -ErrorAction SilentlyContinue)) {
        Add-PrinterDriver -Name 'Generic / Text Only' -ErrorAction Stop
      }
      Add-Printer -Name 'AIBA Chek Printer' -DriverName 'Generic / Text Only' -PortName $port.Name -ErrorAction Stop
      $printer = 'AIBA Chek Printer'
      Write-Output "AIBA: printer avtomatik o'rnatildi: $printer"
    } catch {
      Fail ("Printer Windows'ga o'rnatilmagan va avtomatik o'rnatib bo'lmadi (" + $_.Exception.Message + "). Printer drayverini o'rnating yoki Sozlamalarda nomini kiriting.")
    }
  }
}
$bytes = [System.IO.File]::ReadAllBytes($env:AIBA_BINFILE)
try {
  [AibaRawPrint]::Send($printer, $bytes)
} catch {
  $names = @(Get-CimInstance -Class Win32_Printer -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join '; '
  Fail ("Chop etish xatosi (" + $printer + "): " + $_.Exception.Message + " | Mavjud printerlar: " + $names)
}
''';

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

// NetworkPrinter (esc_pos_printer) is built on the older `esc_pos_utils`
// package, so its PaperSize/CapabilityProfile come from there. The receipt
// byte stream itself is produced by ReceiptBuilder using esc_pos_utils_plus —
// the output is a plain List<int>, so the two packages interoperate cleanly.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as w32;
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

  /// Z-HISOBOT chekini chiqaradi (smena yopilganda).
  Future<PrintReport> printZReport(List<int> bytes) async {
    if (_config.printerUsb) return _sendLocal(bytes);
    final host = _config.printerHost;
    if (host != null && host.isNotEmpty) return _sendNetwork(host, bytes);
    if (Platform.isWindows || Platform.isMacOS) return _sendLocal(bytes);
    return const PrintReport(
      PrintOutcome.noPrinter,
      'Printer sozlanmagan — Z-hisobot faqat ekranda',
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
      // Qayerga ketgani ko'rsatiladi — noto'g'ri IP'ga «muvaffaqiyatli»
      // ketib qog'oz chiqmasligini kassir darhol payqaydi.
      return PrintReport(PrintOutcome.printed,
          'Chek chop etildi → IP $host:${_config.printerPort}');
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
  /// To'g'ridan-to'g'ri winspool (FFI) orqali RAW yozish — PowerShell'siz.
  /// `cmd copy /b \\localhost\PRINTER` bilan AYNAN bir xil mexanizm.
  /// null = muvaffaqiyat, aks holda xato matni.
  static String? _win32RawPrint(String printerName, List<int> bytes) {
    return using((arena) {
      var name = printerName.trim();
      if (name.isEmpty) {
        // Nom kiritilmagan — Windows standart printeri.
        final len = arena<Uint32>()..value = 512;
        final buf = arena<Uint16>(512).cast<Utf16>();
        if (w32.GetDefaultPrinter(buf, len.cast()) == 0) {
          return 'Standart printer topilmadi — Sozlamalarda printer nomini kiriting';
        }
        name = buf.toDartString();
      }
      final hOut = arena<IntPtr>();
      if (w32.OpenPrinter(
              name.toNativeUtf16(allocator: arena), hOut, nullptr) ==
          0) {
        return 'Printer ochilmadi: "$name" (Win32 ${w32.GetLastError()}) — '
            'nom Windows\'dagi bilan aynan bir xilmi?';
      }
      final h = hOut.value;
      try {
        final di = arena<w32.DOC_INFO_1>();
        di.ref.pDocName = 'AIBA POS'.toNativeUtf16(allocator: arena);
        di.ref.pOutputFile = nullptr;
        di.ref.pDatatype = 'RAW'.toNativeUtf16(allocator: arena);
        if (w32.StartDocPrinter(h, 1, di.cast()) == 0) {
          return 'StartDocPrinter xato (Win32 ${w32.GetLastError()})';
        }
        try {
          w32.StartPagePrinter(h);
          final data = arena<Uint8>(bytes.length);
          data.asTypedList(bytes.length).setAll(0, bytes);
          final written = arena<Uint32>();
          final ok =
              w32.WritePrinter(h, data.cast(), bytes.length, written);
          w32.EndPagePrinter(h);
          if (ok == 0 || written.value != bytes.length) {
            return 'WritePrinter xato (Win32 ${w32.GetLastError()})';
          }
        } finally {
          w32.EndDocPrinter(h);
        }
        return null;
      } finally {
        w32.ClosePrinter(h);
      }
    });
  }

  /// Sessiya davomida bir marta aniqlangan ishonchli navbat nomi.
  static String? _winQueueCache;

  Future<PrintReport> _sendWindows(List<int> bytes) async {
    // Yangi oqim: (1) ishonchli RAW navbatni ANIQLAB olamiz (Generic/Text
    // Only, kerak bo'lsa o'zimiz o'rnatamiz), (2) FFI bilan yozamiz,
    // (3) hujjat navbatdan CHIQIB KETGANINI tekshiramiz — chiqmasa bu XATO
    // (avval "chop etildi" deb yolg'on aytilib qog'oz chiqmasdi), avto
    // rejimda navbat portini o'zimiz davolab bir marta qayta urinamiz.
    final cfgName = _config.printerName;
    String? queue = cfgName.isNotEmpty ? cfgName : _winQueueCache;
    if (queue == null || queue.isEmpty) {
      queue = await _ensureWindowsQueue();
      if (queue != null) _winQueueCache = queue;
    }
    if (queue == null || queue.isEmpty) {
      // Sozlash skripti ishlamadi — eski PowerShell yo'liga tushamiz.
      return _sendWindowsPs(bytes);
    }

    var err = _win32RawPrint(queue, bytes);
    if (err != null && cfgName.isEmpty) {
      // Kesh eskirgan bo'lishi mumkin (printer o'chirilgan) — qayta aniqlaymiz.
      debugPrint('[PrinterService] win32 ffi: $err — navbat qayta aniqlanadi');
      _winQueueCache = null;
      final fresh = await _ensureWindowsQueue();
      if (fresh != null && fresh != queue) {
        queue = fresh;
        _winQueueCache = fresh;
        err = _win32RawPrint(queue, bytes);
      }
    }
    if (err != null) {
      debugPrint('[PrinterService] win32 ffi: $err');
      return cfgName.isNotEmpty
          ? PrintReport(PrintOutcome.failed, err)
          : _sendWindowsPs(bytes);
    }

    // Hujjat haqiqatan chiqdimi? Tiqilib qolsa — o'lik port.
    var stuck = await _winQueueStuck(queue);
    if (stuck == 0) {
      return PrintReport(PrintOutcome.printed, 'Chek chop etildi → $queue');
    }
    if (cfgName.isEmpty) {
      // Avto-davolash: navbatni boshqa jonli USB portga o'tkazib qayta urinish
      // (mijoz kassasidagi "USB001 o'lik, USB002 jonli" holati).
      final newPort = await _healWindowsQueue(queue);
      if (newPort != null) {
        err = _win32RawPrint(queue, bytes);
        if (err == null) {
          stuck = await _winQueueStuck(queue);
          if (stuck == 0) {
            return PrintReport(PrintOutcome.printed,
                'Chek chop etildi → $queue ($newPort portga o\'tkazildi)');
          }
        }
      }
    }
    return PrintReport(
        PrintOutcome.failed,
        "'$queue' navbatida hujjat TIQILIB qoldi — printer bu portga "
        'ulanmagan. USB kabelni tekshiring yoki Sozlamalarda ISHLAYDIGAN '
        'printer nomini kiriting.');
  }

  /// PowerShell skriptni vaqtinchalik .ps1 (UTF-8 BOM) orqali ishga tushiradi.
  Future<String?> _runPs(String script,
      {Map<String, String> env = const {},
      Duration timeout = const Duration(seconds: 25)}) async {
    try {
      final tmp = Directory.systemTemp.path;
      final ps1 =
          '$tmp\\aiba-ps-${DateTime.now().microsecondsSinceEpoch}.ps1';
      await File(ps1).writeAsBytes(
          [0xEF, 0xBB, 0xBF, ...utf8.encode(script)],
          flush: true);
      try {
        final res = await Process.run(
          'powershell',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1],
          environment: env,
        ).timeout(timeout);
        if (res.exitCode != 0) {
          debugPrint('[PrinterService] ps: ${res.stderr}');
          return null;
        }
        return res.stdout.toString();
      } finally {
        try {
          await File(ps1).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PrinterService] ps exception: $e');
      return null;
    }
  }

  /// Ishonchli RAW navbatni topadi yoki O'ZI O'RNATADI — natija navbat nomi.
  /// Ustuvorlik: mavjud Generic/Text Only navbat → chek-printerning portiga
  /// 'AIBA Chek Printer' (Generic/Text Only) yaratish/tuzatish.
  Future<String?> _ensureWindowsQueue() async {
    final out = await _runPs(_winEnsureQueueScript);
    if (out == null) return null;
    final m = RegExp(r'AIBA-QUEUE: ([^\r\n]+)').firstMatch(out);
    final name = m?.group(1)?.trim();
    if (name != null && name.isNotEmpty) {
      debugPrint('[PrinterService] windows navbat: $name');
      return name;
    }
    return null;
  }

  /// 2 soniyadan keyin navbatdagi hujjatlar soni (0 = chiqib ketdi).
  /// Tiqilganlarini o'chirib ham yuboradi — keyingi urinishlarga xalaqit
  /// bermasin.
  Future<int> _winQueueStuck(String queue) async {
    final out = await _runPs(r'''
Start-Sleep -Milliseconds 2000
$j = @(Get-PrintJob -PrinterName $env:AIBA_Q -ErrorAction SilentlyContinue)
if ($j.Count -gt 0) {
  $j | Remove-PrintJob -ErrorAction SilentlyContinue
}
Write-Output ("AIBA-STUCK: " + $j.Count)
''', env: {'AIBA_Q': queue});
    if (out == null) return 0; // tekshirib bo'lmadi — muvaffaqiyat deb olamiz
    final m = RegExp(r'AIBA-STUCK: (\d+)').firstMatch(out);
    return int.tryParse(m?.group(1) ?? '0') ?? 0;
  }

  /// Navbatni boshqa jonli USB/ESDPRT portga o'tkazadi (faqat Generic/Text
  /// Only drayverli navbat uchun). Natija — yangi port nomi yoki null.
  Future<String?> _healWindowsQueue(String queue) async {
    final out = await _runPs(r'''
$q = Get-Printer -Name $env:AIBA_Q -ErrorAction SilentlyContinue
if ($q -eq $null) { exit 1 }
if ($q.DriverName -notmatch 'Generic') { exit 1 }
$ports = @(Get-PrinterPort -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^(USB\d|ESDPRT)' -and $_.Name -ne $q.PortName } |
  ForEach-Object { $_.Name })
if ($ports.Count -eq 0) { exit 1 }
Set-Printer -Name $env:AIBA_Q -PortName $ports[0] -ErrorAction Stop
Write-Output ("AIBA-PORT: " + $ports[0])
''', env: {'AIBA_Q': queue});
    if (out == null) return null;
    return RegExp(r'AIBA-PORT: ([^\r\n]+)').firstMatch(out)?.group(1)?.trim();
  }

  Future<PrintReport> _sendWindowsPs(List<int> bytes) async {
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
        // Qaysi printerga ketgani ko'rsatiladi — «chop etildi lekin qog'oz
        // chiqmadi» holatida kassir noto'g'ri printer tanlanganini darhol
        // ko'radi (Sozlamalarda aniq nomini kiritib tuzatadi).
        final out = res.stdout.toString();
        final picked = RegExp(r"AIBA-OK: ([^\n]+)")
                .firstMatch(out)
                ?.group(1)
                ?.trim() ??
            RegExp(r"AIBA: [^\n]*?: ([^\n]+)")
                .allMatches(out)
                .map((m) => m.group(1)!.trim())
                .lastOrNull;
        return PrintReport(
            PrintOutcome.printed,
            picked == null
                ? 'Chek chop etildi'
                : 'Chek chop etildi → $picked');
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

  // Ishonchli RAW navbatni topish/o'rnatish skripti. Drayverli navbatlar
  // (masalan XP-80C) RAW baytlarni ba'zan yutib yuboradi yoki o'lik portda
  // turadi — shuning uchun Generic/Text Only navbat afzal, bo'lmasa chek
  // printerning portiga o'zimiz yaratamiz. Bir marta ishlaydi, natija
  // keshlanadi.
  static const String _winEnsureQueueScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$virtual = 'Print to PDF|XPS|OneNote|Fax|AnyDesk|PDF24|Foxit|Adobe PDF'
$all = @(Get-CimInstance -Class Win32_Printer | Where-Object { ($_.Name + ' ' + $_.DriverName) -notmatch $virtual })
# 1) Tayyor Generic / Text Only navbat bormi? (AIBARAW, AIBA Chek Printer...)
$gen = @($all | Where-Object { $_.DriverName -match 'Generic' } |
  Sort-Object -Property @{Expression={$_.Name -match 'AIBA'};Descending=$true},
                        @{Expression={$_.Default};Descending=$true})
if ($gen.Count -gt 0) { Write-Output ("AIBA-QUEUE: " + $gen[0].Name); exit 0 }
# 2) Chek printerga o'xshagan printerning PORTINI olamiz.
$kw = 'POS|THERM|RECEIPT|CHEK|AIBA|XPRINTER|XP-|RONGTA|RP-|TM-|GP-|GOOJPRT|SEWOO|BIXOLON|CITIZEN|ZYWELL|HOIN|OCPP|(^|[^0-9])(58|80)([^0-9]|$)'
$usbPort = '^(USB|ESDPRT|POS)'
$cand = @($all | Where-Object { ($_.Name + ' ' + $_.DriverName) -match $kw } |
  Sort-Object -Property @{Expression={$_.Default};Descending=$true},
                        @{Expression={-not $_.WorkOffline};Descending=$true},
                        @{Expression={$_.PortName -match $usbPort};Descending=$true})
if ($cand.Count -eq 0) { $cand = @($all | Where-Object { $_.PortName -match $usbPort }) }
if ($cand.Count -eq 0) { $cand = @($all | Where-Object { $_.Default }) }
$port = $null
if ($cand.Count -gt 0) { $port = $cand[0].PortName }
if ($port -eq $null) {
  $p = @(Get-PrinterPort | Where-Object { $_.Name -match '^(USB\d|ESDPRT)' }) | Select-Object -First 1
  if ($p -ne $null) { $port = $p.Name }
}
if ($port -eq $null) { exit 1 }
# 3) Shu portga Generic / Text Only navbat yaratamiz (bor bo'lsa portini tuzatamiz).
$ErrorActionPreference = 'Stop'
try {
  if (-not (Get-PrinterDriver -Name 'Generic / Text Only' -ErrorAction SilentlyContinue)) {
    Add-PrinterDriver -Name 'Generic / Text Only'
  }
  $exist = Get-Printer -Name 'AIBA Chek Printer' -ErrorAction SilentlyContinue
  if ($exist -eq $null) {
    Add-Printer -Name 'AIBA Chek Printer' -DriverName 'Generic / Text Only' -PortName $port
  } elseif ($exist.PortName -ne $port) {
    Set-Printer -Name 'AIBA Chek Printer' -PortName $port
  }
  Write-Output "AIBA-QUEUE: AIBA Chek Printer"
} catch { exit 1 }
''';

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
    Sort-Object -Property @{Expression={$_.Default};Descending=$true},
                          @{Expression={-not $_.WorkOffline};Descending=$true},
                          @{Expression={$_.PortName -match $usbPort};Descending=$true})
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
# Hujjat navbatdan CHIQIB KETDIMI — 2 soniya kutib tekshiramiz. Tiqilib
# qolsa (o'lik port/navbat) bu XATO deb qaytariladi: "chop etildi" degan
# yolg'on xabar o'rniga kassir aniq sababni ko'radi.
Start-Sleep -Milliseconds 2000
$stuck = @(Get-PrintJob -PrinterName $printer -ErrorAction SilentlyContinue)
if ($stuck.Count -gt 0) {
  Fail ("'" + $printer + "' navbatida hujjat TIQILIB qoldi (" + $stuck.Count + " ta) - bu navbat printerga ulanmagan (o'lik port). Windows'da probniy chiqqan ISHLAYDIGAN printer nomini Sozlamalarga yozing.")
}
Write-Output ("AIBA-OK: " + $printer)
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

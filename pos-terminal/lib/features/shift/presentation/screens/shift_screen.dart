import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../printing/data/receipt_builder.dart';
import '../../../printing/presentation/printing_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';

/// Ish vaqti (Smena) — Figma "Pos Design": statistik kartalar, smena
/// boshlash/yopish, o'ngda Top mahsulotlar. Qorong'i panel, suv fonида.
class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  Timer? _refresh;

  /// Oxirgi yopilgan smena (Z) — printer xato bersa qayta chiqarish uchun.
  Shift? _lastZ;

  @override
  void initState() {
    super.initState();
    // Kassir mishka ishlatmaydi: Enter — smenani boshlash, Z — yopish.
    // Global handler (fokus qayerda bo'lishidan qat'i nazar ishlaydi).
    HardwareKeyboard.instance.addHandler(_onKey);
    // Ekranga kirilganda statistika serverdan qayta so'raladi — aks holda
    // smena ochilgandagi (nol) qiymatlar ko'rinib turadi. Har 30 soniyada
    // yangilanadi: savdo jamlari va smena davomiyligi jonli bo'ladi.
    Future.microtask(() {
      if (mounted) ref.invalidate(currentShiftProvider);
    });
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(currentShiftProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Smena ochish/yopish — FAQAT menejer. Kassir faqat savdo qiladi.
  bool get _isManager =>
      (ref.read(sessionProvider)?.staff.role ?? '') != 'cashier';

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (!_isManager) return false;
    final shift = ref.read(currentShiftProvider).valueOrNull;
    final isOpen = shift != null && shift.isOpen;
    final k = event.logicalKey;
    if (!isOpen &&
        (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter)) {
      _open(context, ref);
      return true;
    }
    if (isOpen && k == LogicalKeyboardKey.keyZ) {
      _close(context, ref, shift.id);
      return true;
    }
    return false;
  }

  /// Smena nomi — 2 ta 12 soatlik smena: 12:00–00:00 kunduzgi, 00:00–12:00
  /// tunggi. Ochilgan vaqtiga qarab aniqlanadi.
  static String _shiftName(DateTime? openedAt) {
    if (openedAt == null) return '';
    final h = openedAt.toLocal().hour;
    return h >= 12 ? 'Kunduzgi smena (12:00–00:00)' : 'Tunggi smena (00:00–12:00)';
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    // Boshlang'ich kassa summasi shu oynada kiritiladi (klaviaturadan,
    // Enter — tasdiqlash). Bo'sh qoldirilsa 0.
    final result = await showDialog<num>(
      context: context,
      builder: (_) => const _PosDialog(
        title: 'Smenani boshlash',
        bodyTitle: 'Smenani boshlash',
        message: 'Boshlang\'ich kassadagi naqd summani kiriting. '
            'Smena boshlangandan so\'ng savdolarni amalga oshirishingiz mumkin',
        amountLabel: 'Boshlang\'ich kassa (so\'m)',
      ),
    );
    if (result == null) return;
    try {
      final shift = await ref.read(shiftRepositoryProvider).open(result);
      ref.read(sessionProvider.notifier).setShiftId(shift.id);
      ref.invalidate(currentShiftProvider);
    } catch (e) {
      if (context.mounted) _snack(context, 'Xato: $e');
    }
  }

  Future<void> _close(
      BuildContext context, WidgetRef ref, String shiftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const _PosDialog(
        title: 'Smenani yopish (z)',
        bodyTitle: 'Smenani yakunlash',
        message: 'Smena yopilgandan so\'ng uning hisoboti shakllantiriladi '
            'va smenani davom ettirib bo\'lmaydi',
      ),
    );
    if (confirm != true) return;
    try {
      final z = await ref.read(shiftRepositoryProvider).close(shiftId: shiftId);
      ref.read(sessionProvider.notifier).setShiftId(null);
      ref.invalidate(currentShiftProvider);
      if (context.mounted) _snack(context, 'Smena yopildi — Z-hisobot chiqarilmoqda');
      // Z-HISOBOT cheki: smena kesimi (naqd/karta/Click/Uzum/keldi-ketdi,
      // rasxod, xato cheklar) qog'ozda. Fonda — printer sekin bo'lsa ham
      // oqim bloklanmaydi.
      _lastZ = z;
      // ignore: unawaited_futures
      _printZReport(z);
    } catch (e) {
      if (context.mounted) _snack(context, 'Xato: $e');
    }
  }

  Future<void> _printZReport(Shift z) async {
    try {
      final ses = ref.read(sessionProvider);
      // "Sotilganlar" ro'yxati Z-chekka QO'SHILMAYDI — mahsulot ko'p
      // restoranда chek juda uzun bo'lib ketadi (foydalanuvchi talabi).
      final bytes = await ReceiptBuilder.buildZReport(
        restaurantName: ses?.restaurant.name ?? 'AIBA',
        shiftName: _shiftName(z.openedAt),
        staffName: ses?.staff.name,
        openedAt: z.openedAt,
        closedAt: z.closedAt,
        ordersCount: z.ordersCount,
        totalSales: z.totalSales,
        cash: z.totalCash,
        card: z.cardOnly,
        click: z.clickTotal,
        uzum: z.uzumTotal,
        keldi: z.keldiTotal,
        openingCash: z.openingCash,
        expenses: z.expensesTotal,
        errorChecks: z.errorChecksCount,
        errorTotal: z.errorChecksTotal,
        cashQrTotal: z.cashQrTotal,
        cashQrCount: z.cashQrCount,
        cashNoQrTotal: z.cashNoQrTotal,
        cashNoQrCount: z.cashNoQrCount,
        paperWidth: ses?.restaurant.receiptPaperWidth ?? 80,
      );
      await ref.read(printerServiceProvider).printZReport(bytes);
    } catch (_) {
      if (mounted) _snack(context, 'Z-hisobot chop etilmadi (printer)');
    }
  }

  /// «Sotilganlar» chekini chiqarish — menejer xohlasa (Z'ga kirmaydi).
  Future<void> _printSoldItems(Shift shift) async {
    try {
      final ses = ref.read(sessionProvider);
      final res = await ref.read(dioClientProvider).get(
          '/api/v2/pos-terminal/reports/top-products?shift_id=${shift.id}&limit=100');
      final list =
          ((res.data is Map ? res.data['items'] : null) as List?) ?? const [];
      final items = list
          .map((e) => ZItem(
                name: ((e as Map)['name'] ?? '').toString(),
                qty: num.tryParse('${e['qty']}') ?? 0,
                amount: num.tryParse('${e['amount']}') ?? 0,
              ))
          .toList();
      final bytes = await ReceiptBuilder.buildSoldItems(
        restaurantName: ses?.restaurant.name ?? 'AIBA',
        shiftName: _shiftName(shift.openedAt),
        items: items,
        paperWidth: ses?.restaurant.receiptPaperWidth ?? 80,
      );
      final rep = await ref.read(printerServiceProvider).printZReport(bytes);
      if (mounted) _snack(context, rep.message);
    } catch (_) {
      if (mounted) _snack(context, 'Sotilganlar cheki chiqmadi (printer/tarmoq)');
    }
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(currentShiftProvider);
    final session = ref.watch(sessionProvider);
    final staffName = session?.staff.name ?? 'Xodim';
    final kassa = session?.terminal.name ?? 'Kassa';

    return LayoutBuilder(builder: (context, bc) {
      // Kichik kassa ekrani (moноblok ~1024px): «Top mahsulotlar» paneli
      // torayadi yoki butunlay yashirinadi — asosiy statistika birinchi.
      final w = bc.maxWidth;
      final panelW = w >= 1240 ? 340.0 : (w >= 1020 ? 260.0 : 0.0);
      final compact = w < 1020;
      return Padding(
      // Yangilash/avatar chap menyuga ko'chdi — tepada bo'sh joy kerak emas.
      padding: EdgeInsets.fromLTRB(4, compact ? 10 : 16, compact ? 10 : 16,
          compact ? 10 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: PosColors.panel,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.all(compact ? 14 : 24),
              // Darhol chiziladi (spinner o'rniga) — ma'lumot kelgach yangilanadi.
              child: _dashboard(
                  context, ref, shiftAsync.valueOrNull, staffName, kassa),
            ),
          ),
          if (panelW > 0) ...[
            const SizedBox(width: 16),
            SizedBox(width: panelW, child: const _TopProductsPanel()),
          ],
        ],
      ),
    );
    });
  }

  Widget _dashboard(BuildContext context, WidgetRef ref, Shift? shift,
      String staffName, String kassa) {
    final isOpen = shift != null && shift.isOpen;
    final ordersCount = shift?.ordersCount ?? 0;
    final totalSales = shift?.totalSales ?? 0;
    final totalCash = shift?.totalCash ?? 0;
    final opening = shift?.openingCash ?? 0;
    final avg = ordersCount > 0 ? (totalSales / ordersCount) : 0;
    // Smena davomiyligi + boshlanish vaqti (Figma sarlavhasi).
    final startedAt = shift?.openedAt?.toLocal();
    final startTime = startedAt == null
        ? null
        : '${startedAt.hour.toString().padLeft(2, '0')}:'
            '${startedAt.minute.toString().padLeft(2, '0')}';
    String? durationStr;
    if (isOpen && startedAt != null) {
      final d = DateTime.now().difference(startedAt);
      final h = d.inHours;
      final m = d.inMinutes % 60;
      durationStr = h > 0 ? '$h soat $m daqiqa' : '$m daqiqa';
    }

    final errorChecks = shift?.errorChecksCount ?? 0;
    // Samaradorlik: xatosiz cheklar ulushi (ma'lumot bo'lmasa 0%).
    final efficiency = ordersCount > 0
        ? (((ordersCount - errorChecks) / ordersCount) * 100).round()
        : 0;

    // Naqd/Karta bu yerda TAKRORLANMAYDI — pastdagi to'lov kesimi qatorida
    // (Naqd / Karta / Click / Uzum) bir marta ko'rsatiladi.
    final statsRow = Row(
      children: [
        _StatCard(
            iconAsset: 'assets/icons/stat_receipt.svg',
            label: 'Bugungi buyurtmalar',
            value: '$ordersCount ta'),
        const SizedBox(width: 14),
        _StatCard(
            iconAsset: 'assets/icons/stat_chart.svg',
            label: 'Jami savdo',
            value: Money.formatSom(totalSales)),
      ],
    );

    final staffRow = Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
              color: PosColors.green, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(staffName.isEmpty ? 'A' : staffName[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(staffName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Text(
                  isOpen && startTime != null
                      ? '$kassa · ${_shiftName(startedAt)} · Boshlangan: $startTime'
                      : '$kassa · Boshlanmagan',
                  style:
                      const TextStyle(color: PosColors.muted, fontSize: 13)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusBadge(active: isOpen),
            const SizedBox(height: 6),
            Text(durationStr ?? '0 daqiqa',
                style: const TextStyle(color: PosColors.muted, fontSize: 13)),
          ],
        ),
      ],
    );

    // Plitkalar: keng ekranда bitta qatorda, kichik kassa ekranida (tor)
    // 2 tadan bo'lib joylashadi — siqilib «har xil» ko'rinmaydi.
    Widget tileRows(List<Widget> tiles, bool compact, {int perRow = 2}) {
      if (!compact) {
        return Row(children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            tiles[i],
          ],
        ]);
      }
      final rows = <Widget>[];
      for (var i = 0; i < tiles.length; i += perRow) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
        final chunk = tiles.sublist(
            i, (i + perRow > tiles.length) ? tiles.length : i + perRow);
        rows.add(Row(children: [
          for (var j = 0; j < chunk.length; j++) ...[
            if (j > 0) const SizedBox(width: 10),
            chunk[j],
          ],
        ]));
      }
      return Column(children: rows);
    }

    final miniTiles = <Widget>[
      _MiniTile(label: 'Boshlang\'ich kassa', value: Money.formatSom(opening)),
      // Joriy kassa = boshlang'ich + naqd savdo − rasxodlar.
      _MiniTile(
          label: 'Joriy kassa',
          value: Money.formatSom(
              opening + totalCash - (shift?.expensesTotal ?? 0)),
          valueColor: PosColors.green),
      // Manager Telegram botga «rasxod 50000 izoh» deb yozadi.
      _MiniTile(
          label: 'Rasxod',
          value: Money.formatSom(shift?.expensesTotal ?? 0),
          valueColor: PosColors.red),
      _MiniTile(
          label: 'Jami daromad',
          value: Money.formatSom(totalSales),
          valueColor: PosColors.green),
    ];

    // To'lov turlari kesimi: Naqd / Karta / Click / Uzum — har biri alohida
    // (admin paneldagi hisobot bilan bir xil).
    final payTiles = <Widget>[
      _MiniTile(label: 'Naqd savdo', value: Money.formatSom(totalCash)),
      _MiniTile(
          label: 'Karta savdo', value: Money.formatSom(shift?.cardOnly ?? 0)),
      _MiniTile(
          label: 'Click savdo',
          value: Money.formatSom(shift?.clickTotal ?? 0)),
      _MiniTile(
          label: 'Uzum savdo', value: Money.formatSom(shift?.uzumTotal ?? 0)),
    ];

    final centerTiles = <Widget>[
      _CenterTile(value: '$ordersCount ta', label: 'Buyurtmalar'),
      _CenterTile(
          value: errorChecks > 0 ? '$errorChecks ta' : '-',
          label: errorChecks > 0
              ? 'Xato cheklar · ${Money.formatSom(shift?.errorChecksTotal ?? 0)}'
              : 'Xato cheklar',
          valueColor: PosColors.red),
      _CenterTile(
          value: ordersCount > 0 ? Money.formatSom(avg) : '0 so\'m',
          label: 'O\'rtacha chek'),
      _CenterTile(
          value: '$efficiency%',
          label: 'Samaradorlik',
          valueColor: PosColors.green),
      // Bugungi keldi-ketdi (VIP comp) cheklar soni.
      _CenterTile(
          value: '${ref.watch(keldiKetdiTodayProvider).valueOrNull ?? 0} ta',
          label: 'Keldi-ketdi',
          valueColor: const Color(0xFFF5A623)),
    ];

    return LayoutBuilder(builder: (context, dc) {
      final compact = dc.maxWidth < 720;
      final gap = compact ? 12.0 : 18.0;
      return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Figma: smena FAOL bo'lsa xodim qatori tepada, bo'lmasa statlar.
        if (isOpen) staffRow else statsRow,
        SizedBox(height: gap),
        if (isOpen) statsRow else staffRow,
        SizedBox(height: gap),
        // 3) Boshlang'ich kassa / Joriy kassa / Jami daromad — to'liq summa
        // ("50 000 so'm"), qisqartma ("50 K") kassirni chalg'itadi.
        tileRows(miniTiles, compact),
        const SizedBox(height: 14),
        tileRows(payTiles, compact),
        // Naqd savdoning fiskal kesimi: menejer «naqdning qanchasi soliqda
        // QR olgan, qanchasi hali QRsiz» — bir qarashda. Cheklarning o'zi
        // F12 (Cheklar tarixi) dan chiqariladi.
        if ((shift?.cashQrCount ?? 0) + (shift?.cashNoQrCount ?? 0) > 0) ...[
          const SizedBox(height: 14),
          tileRows(<Widget>[
            _MiniTile(
                label: 'Naqd · QR chiqarilgan (${shift?.cashQrCount ?? 0} ta)',
                value: Money.formatSom(shift?.cashQrTotal ?? 0),
                valueColor: PosColors.green),
            _MiniTile(
                label: 'Naqd · QRsiz (${shift?.cashNoQrCount ?? 0} ta)',
                value: Money.formatSom(shift?.cashNoQrTotal ?? 0),
                valueColor: const Color(0xFFF5A623)),
          ], compact),
        ],
        const SizedBox(height: 14),
        // 5) Markazlashgan ko'rsatkichlar (Figma) — torда 3+2 bo'lib.
        tileRows(centerTiles, compact, perRow: 3),
        const SizedBox(height: 18),
        // 6) Boshlash / yopish tugmasi — FAQAT menejer. Kassir bu ekranni
        // ko'rmaydi ham, lekin qo'shimcha himoya sifatida tugma yashiriladi.
        if (_isManager)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: isOpen
                ? _BigButton(
                    label: 'Smenani yopish (z)',
                    icon: Icons.power_settings_new,
                    color: const Color(0x33E5484D),
                    textColor: PosColors.red,
                    onTap: () => _close(context, ref, shift.id),
                  )
                : _BigButton(
                    label: '→  Smenani boshlash  (Enter)',
                    icon: Icons.arrow_forward,
                    color: PosColors.blue,
                    textColor: Colors.white,
                    onTap: () => _open(context, ref),
                  ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PosColors.cardBorder),
            ),
            child: const Text('Smenani faqat menejer ochadi va yopadi',
                style: TextStyle(color: PosColors.muted, fontSize: 14)),
          ),
        // Menejer qo'shimcha cheklari: sotilganlar (istasa) va oxirgi Z
        // nusxasi (printer xato bergan bo'lsa).
        if (_isManager && (isOpen || _lastZ != null)) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (isOpen)
              Expanded(
                child: _BigButton(
                  label: 'Sotilganlar cheki',
                  icon: Icons.receipt_long,
                  color: PosColors.card,
                  textColor: Colors.white,
                  onTap: () => _printSoldItems(shift),
                ),
              ),
            if (isOpen && _lastZ != null) const SizedBox(width: 10),
            if (_lastZ != null)
              Expanded(
                child: _BigButton(
                  label: 'Oxirgi Z nusxasi',
                  icon: Icons.print,
                  color: PosColors.card,
                  textColor: Colors.white,
                  onTap: () => _printZReport(_lastZ!),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 18),
        // 7) Amalga oshmagan buyurtmalar (Figma) — real ro'yxat.
        const _FailedOrdersSection(),
      ],
      ),
    );
    });
  }
}

/// "Amalga oshmagan buyurtmalar" — bugungi bekor qilingan / xato urilgan
/// cheklar ro'yxati (Figma: sana, summa, №, qizil/sariq pill).
class _FailedOrdersSection extends ConsumerWidget {
  const _FailedOrdersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(failedOrdersProvider);
    final items = async.valueOrNull ?? const <FailedOrder>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Amalga oshmagan buyurtmalar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: PosColors.red, shape: BoxShape.circle),
                child: Text('${items.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          if (items.isEmpty) ...[
            const SizedBox(height: 26),
            const Center(
              child: Column(children: [
                Icon(Icons.bar_chart, size: 56, color: Color(0xFF3A3D42)),
                SizedBox(height: 14),
                Text('Hozircha amal qilmagan cheklar yoq',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                    'Agar chek xato urilgan yoki bekor qilingan bo\'lsa shu yerda ko\'rsatiladi',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PosColors.muted, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++) ...[
              _FailedRow(order: items[i]),
              if (i < items.length - 1)
                const Divider(height: 1, color: PosColors.cardBorder),
            ],
          ],
        ],
      ),
    );
  }
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.order});
  final FailedOrder order;

  String get _date {
    final d = order.createdAt?.toLocal();
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} (${two(d.hour)}:${two(d.minute)})';
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = order.cancelled;
    final pillColor = cancelled ? PosColors.red : const Color(0xFFF5A623);
    final pillLabel = cancelled ? 'Bekor qilingan' : 'Xato urilgan';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_date,
                    style:
                        const TextStyle(color: PosColors.muted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(Money.formatSom(order.total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                if ((order.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(order.note!,
                      style: const TextStyle(
                          color: PosColors.muted, fontSize: 12)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('№ ${order.number}',
                  style: const TextStyle(color: PosColors.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.close, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(pillLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Markazlashgan ko'rsatkich (Figma: qiymat tepada, nomi pastda).
class _CenterTile extends StatelessWidget {
  const _CenterTile(
      {required this.value, required this.label, this.valueColor});
  final String value;
  final String label;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: PosColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosColors.cardBorder),
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: PosColors.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final c = active ? PosColors.green : PosColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(active ? 'Faol smena' : 'Smena faol emas',
            style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.iconAsset, required this.label, required this.value});
  final String iconAsset;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF), // Figma: oq 8%
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(iconAsset,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                    Colors.white, BlendMode.srcIn)),
            const SizedBox(height: 14),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: PosColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PosColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: PosColors.muted, fontSize: 13)),
            const SizedBox(height: 8),
            // Summa BITTA qatorda — sig'masa avtomatik kichrayadi.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _TopProductsPanel extends ConsumerWidget {
  const _TopProductsPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topProductsProvider);
    return Container(
      decoration: BoxDecoration(
        color: PosColors.panel,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Figma: sarlavha chip/quticha ichida.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PosColors.cardBorder),
            ),
            child: const Text('Top mahsulotlar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: PosColors.blue))),
              error: (_, _) => const _TopEmpty(),
              data: (items) => items.isEmpty
                  ? const _TopEmpty()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _TopRow(item: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopEmpty extends StatelessWidget {
  const _TopEmpty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Color(0xFF3A3D42)),
          SizedBox(height: 16),
          Text('Top mahsulotlar\nmavjud emas',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('Savdolar amalga oshirilgach, eng ko\'p sotilgan '
              'mahsulotlar shu yerda ko\'rsatiladi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PosColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.item});
  final TopProduct item;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mahsulot rasmi (Figma) yoki placeholder.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      errorBuilder: (_, _, _) => const _TopThumb())
                  : const _TopThumb(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _kv('Sotilganlar soni :', '${Money.formatQty(item.qty)} dona'),
                const SizedBox(height: 4),
                _kv('Summa :', Money.formatSom(item.amount)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: PosColors.muted, fontSize: 12)),
          Text(v,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

class _TopThumb extends StatelessWidget {
  const _TopThumb();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosColors.card,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF4A4E55), size: 22),
    );
  }
}

/// Umumiy qorong'i dialog (smena boshlash/yopish) — Figma tuzilishi:
/// soat ikoni + sarlavha, divider, markazda qalin sarlavha + muted matn,
/// divider, [✕ Bekor qilish] (kulrang) + [Tasdiqlash ✓] (ko'k).
class _PosDialog extends StatefulWidget {
  const _PosDialog({
    required this.title,
    required this.bodyTitle,
    required this.message,
    this.amountLabel,
  });
  final String title;
  final String bodyTitle;
  final String message;

  /// null — oddiy tasdiqlash (true qaytadi); berilsa summa maydoni chiqadi
  /// va tasdiqda kiritilgan summa (bo'sh = 0) qaytadi.
  final String? amountLabel;

  @override
  State<_PosDialog> createState() => _PosDialogState();
}

class _PosDialogState extends State<_PosDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (widget.amountLabel != null) {
      final digits = _ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      Navigator.pop(context, num.tryParse(digits) ?? 0);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Summa maydonisiz rejimda ham Enter — Tasdiqlash (klaviatura-first).
      child: Focus(
        autofocus: widget.amountLabel == null,
        onKeyEvent: (node, event) {
          if (widget.amountLabel == null &&
              event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _confirm();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(children: [
                SvgPicture.asset('assets/icons/nav_shift.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn)),
                const SizedBox(width: 12),
                Text(widget.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            const Divider(height: 1, color: PosColors.cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
              child: Column(children: [
                Text(widget.bodyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: PosColors.muted, fontSize: 14, height: 1.45)),
                if (widget.amountLabel != null) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsInputFormatter()],
                    onSubmitted: (_) => _confirm(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: widget.amountLabel,
                      labelStyle: const TextStyle(
                          color: PosColors.muted, fontSize: 13),
                      hintText: '0',
                      hintStyle: const TextStyle(color: PosColors.muted),
                      filled: true,
                      fillColor: PosColors.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Summani klaviaturada tering · Enter — Tasdiqlash',
                      style: TextStyle(color: PosColors.muted, fontSize: 11)),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: PosColors.cardBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Bekor qilish',
                    leading: Icons.close,
                    color: const Color(0xFF2E2E31),
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogButton(
                    label: 'Tasdiqlash',
                    trailing: Icons.check,
                    color: PosColors.blue,
                    onTap: _confirm,
                  ),
                ),
              ]),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.leading,
    this.trailing,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? leading;
  final IconData? trailing;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (leading != null) ...[
            Icon(leading, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(trailing, color: Colors.white, size: 18),
          ],
        ]),
      ),
    );
  }
}

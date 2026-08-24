import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/widgets/pos_chrome.dart';

/// Figma "Pos Design" dan eksport qilingan delivery ikonlari.
Widget dlvIcon(String name, {double size = 20, Color color = Colors.white}) {
  return SvgPicture.asset(
    'assets/icons/dlv_$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// Yetkazib berish — Figma "Delivery" dizayni pixel-mos:
///  • Kanban: Yangi / Jarayonda / Tayyor / Yetkazilgan / Bekor qilingan
///  • Kartani bosganda — "All Orders" detal (chap ro'yxat 284px + 903px kontent)
/// Ma'lumot Yandex eats / Uzum Tezkor'dan keladi — integratsiya ulanmaguncha
/// namunaviy buyurtmalar bilan ishlaydi (holatlar lokal o'zgaradi).
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

// ─────────── Model ───────────

enum DStage { yangi, jarayonda, tayyor, yetkazilgan, bekor }

class DItem {
  DItem({
    required this.qty,
    required this.name,
    required this.note,
    required this.price,
    required this.group,
  });
  final int qty;
  final String name;
  final String note;
  final int price;
  final String group;
}

class DOrder {
  DOrder({
    required this.number,
    required this.provider,
    required this.stage,
    required this.createdText,
    required this.readyBy,
    required this.customer,
    required this.phone,
    required this.packages,
    required this.comment,
    required this.items,
    this.minutes,
    this.courier,
  });
  final String number;
  final String provider;
  DStage stage;
  final String createdText;
  final String readyBy;
  final String customer;
  final String phone;
  final int packages;
  final String comment;
  final List<DItem> items;
  int? minutes;
  String? courier;

  int get total => items.fold(0, (s, i) => s + i.price);

  String? get statusLine => switch (stage) {
        DStage.tayyor =>
          courier == null ? 'kuryer qidirilmoqda...' : 'kuryer qabul qildi - $courier',
        DStage.yetkazilgan => 'kuryer qabul qildi - ${courier ?? ''}',
        DStage.bekor => 'Bekor qilindi',
        _ => null,
      };
}

String _som(int v) {
  final s = v
      .toString()
      .split('')
      .reversed
      .join()
      .replaceAllMapped(RegExp(r'.{3}'), (m) => '${m.group(0)} ')
      .split('')
      .reversed
      .join()
      .trim();
  return "$s so'm";
}

// Figma tokenlari: Dark/Error #FF3535, Dark/Success #22C55E, Dark/Warning
// #D97706, Dark/Primary #2277EA (tugma to'ldirishi #2273E7).
const _amber = Color(0xFFD97706);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFFF3535);
const _btnBlue = Color(0xFF2273E7);
const _chipBlue = Color(0xFF2277EA);
const _w08 = Color(0x14FFFFFF); // oq 8%
const _w12 = Color(0x1FFFFFFF); // oq 12%
const _w42 = Color(0x6BFFFFFF); // oq 42%

class _StageStyle {
  const _StageStyle(this.title, this.color, this.icon);
  final String title;
  final Color color;
  final String icon; // assets/icons/dlv_<icon>.svg
}

_StageStyle _style(DStage s) => switch (s) {
      DStage.yangi => const _StageStyle('Yangi', _chipBlue, 'package'),
      DStage.jarayonda => const _StageStyle('Jarayonda', _amber, 'soup'),
      DStage.tayyor => const _StageStyle('Tayyor', _green, 'truck'),
      DStage.yetkazilgan => const _StageStyle('Yetkazilgan', _green, 'checks'),
      DStage.bekor => const _StageStyle('Bekor qilingan', _red, 'x'),
    };

// ─────────── Namuna buyurtmalar (aggregator ulanmaguncha) ───────────

List<DOrder> _sampleOrders() {
  List<DItem> items() => [
        DItem(qty: 2, name: 'Lag\'mon', note: '+ qo\'shimcha go\'sht, achchiqsiz', price: 84000, group: 'Issiq Taomlar'),
        DItem(qty: 3, name: 'Lag\'mon', note: '+ qo\'shimcha go\'sht, achchiqsiz', price: 36000, group: 'Issiq Taomlar'),
        DItem(qty: 1, name: 'Coca Cola 0,5 L', note: 'Shakarsiz', price: 12000, group: 'Ichimliklar'),
      ];
  DOrder o(String num, String prov, DStage st, {int? m, String? courier}) => DOrder(
        number: num,
        provider: prov,
        stage: st,
        createdText: 'yaratilgan 10:02 · 2 daqiqa oldin',
        readyBy: '10:40 - 22 daqiqa qoldi',
        customer: 'Dilnoza',
        phone: '+998 90 *** ** 99',
        packages: 2,
        comment: 'Lag\'monni achchiq bo\'lmasin, ichida kartoshka ham bo\'lmasin, iltimos!',
        items: items(),
        minutes: m,
        courier: courier,
      );
  return [
    o('45914', 'Yandex eats', DStage.yangi, m: 22),
    o('45915', 'Uzum Tezkor', DStage.yangi, m: 12),
    o('45916', 'Yandex eats', DStage.yangi, m: 5),
    o('45917', 'Yandex eats', DStage.yangi, m: 28),
    o('45918', 'Uzum Tezkor', DStage.yangi, m: 22),
    o('45920', 'Yandex eats', DStage.jarayonda),
    o('45921', 'Yandex eats', DStage.jarayonda),
    o('45922', 'Uzum Tezkor', DStage.jarayonda),
    o('45923', 'Yandex eats', DStage.jarayonda),
    o('776633', 'Uzum Tezkor', DStage.tayyor),
    o('45925', 'Yandex eats', DStage.tayyor, courier: 'Ahmadjon Boburov'),
    for (var i = 0; i < 7; i++)
      o('4590$i', 'Yandex eats', DStage.yetkazilgan, courier: 'Ahmadjon Boburov'),
    o('45930', 'Uzum Tezkor', DStage.bekor),
    o('45931', 'Yandex eats', DStage.bekor),
    o('45932', 'Yandex eats', DStage.bekor),
    o('45933', 'Yandex eats', DStage.bekor),
  ];
}

// ─────────── Ekran ───────────

class _DeliveryScreenState extends State<DeliveryScreen> {
  final List<DOrder> _orders = _sampleOrders();
  DOrder? _selected;
  Timer? _tick;
  int _accept = 15;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  List<DOrder> _byStage(DStage s) => _orders.where((o) => o.stage == s).toList();

  void _open(DOrder o) {
    _tick?.cancel();
    _accept = 15;
    if (o.stage == DStage.yangi || o.stage == DStage.jarayonda) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _accept = (_accept - 1).clamp(0, 99));
      });
    }
    setState(() => _selected = o);
  }

  void _back() {
    _tick?.cancel();
    setState(() => _selected = null);
  }

  void _advance(DOrder o) {
    setState(() {
      switch (o.stage) {
        case DStage.yangi:
          o.stage = DStage.jarayonda;
        case DStage.jarayonda:
          o.stage = DStage.tayyor;
        default:
          break;
      }
    });
    _open(o);
  }

  void _cancel(DOrder o) {
    setState(() => o.stage = DStage.bekor);
    _open(o);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (n, e) {
        if (_selected != null &&
            e is KeyDownEvent &&
            e.logicalKey == LogicalKeyboardKey.escape) {
          _back();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
        child: Container(
          // Figma: kontent paneli Dark/Card #1B1B1C, radius 20.
          decoration: BoxDecoration(
            color: PosColors.card,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: _selected == null ? _board() : _detail(_selected!),
        ),
      ),
    );
  }

  // ─────────── Kanban ───────────

  Widget _board() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Buyurtmalar yig\'ish',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Buyurtmalarni tez va qulay boshqaring',
            style: TextStyle(color: _w42, fontSize: 14)),
        const SizedBox(height: 20),
        // Ustunlar ekran kengligiga moslashadi. Sig'sa — Expanded bilan
        // teng bo'linadi (oshib ketishi MUMKIN EMAS, o'ng tomon bo'sh
        // qolmaydi); sig'masa — gorizontal scroll (Figma 284px).
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            const n = 5, gap = 12.0, minW = 224.0, scrollW = 284.0;
            Widget col(DStage stage) => _KanbanColumn(
                  stage: stage,
                  orders: _byStage(stage),
                  onOpen: _open,
                  onAccept: (o) => setState(() => o.stage = DStage.jarayonda),
                  onReady: (o) => setState(() => o.stage = DStage.tayyor),
                );
            if (c.maxWidth >= n * minW + gap * (n - 1)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < DStage.values.length; i++) ...[
                    Expanded(child: col(DStage.values[i])),
                    if (i < DStage.values.length - 1) const SizedBox(width: gap),
                  ],
                ],
              );
            }
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DStage.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: gap),
              itemBuilder: (_, i) =>
                  SizedBox(width: scrollW, child: col(DStage.values[i])),
            );
          }),
        ),
      ],
    );
  }

  // ─────────── Detal (Figma "All Orders") ───────────

  Widget _detail(DOrder o) {
    final st = _style(o.stage);
    final same = _byStage(o.stage);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chap: Ortga + shu holatdagi buyurtmalar ustuni (Figma: 284px).
        SizedBox(
          width: 284,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _back,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    dlvIcon('arrow-left', size: 24),
                    const SizedBox(width: 6),
                    const Text('Ortga',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _w08,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(children: [
                    _ColumnHeader(stage: o.stage, count: same.length),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: same.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _OrderCard(
                          order: same[i],
                          selected: identical(same[i], o),
                          compact: true,
                          onOpen: () => _open(same[i]),
                          onAccept: () {
                            setState(() => same[i].stage = DStage.jarayonda);
                            _open(same[i]);
                          },
                          onReady: () {
                            setState(() => same[i].stage = DStage.tayyor);
                            _open(same[i]);
                          },
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        // Vertikal ajratkich (Figma: x=315, 1px oq 12%).
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 15),
          color: _w12,
        ),
        // O'ng: 903px kontent ustuni — cho'zilmaydi (Figma).
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              // Figma 903px; katta monitorда 1200 gacha cho'ziladi — o'ng
              // tomon bo'sh qolmaydi, lekin matn qatorlari cho'zilib ketmaydi.
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chiplar: holat + agregator (Figma: px8 py6, radius 8, 14px).
                  Row(children: [
                    _Chip(
                        text: st.title,
                        bg: o.stage == DStage.yangi
                            ? _chipBlue
                            : st.color.withValues(alpha: 0.16),
                        fg: o.stage == DStage.yangi ? Colors.white : st.color),
                    const SizedBox(width: 12),
                    _Chip(text: o.provider, bg: _chipBlue, fg: Colors.white),
                  ]),
                  const SizedBox(height: 16),
                  // № (32 bold #F0FAFA) + yaratilgan · holat halqasi o'ngda.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('№ ${o.number}',
                                style: const TextStyle(
                                    color: Color(0xFFF0FAFA),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1)),
                            const SizedBox(height: 6),
                            Text(o.createdText,
                                style:
                                    const TextStyle(color: _w42, fontSize: 14)),
                          ],
                        ),
                      ),
                      _StatusRing(stage: o.stage),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 3 ta info karta (oq 8%, radius 9, p12, 14px matn).
                  IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _InfoCard(
                              child: Row(children: [
                                dlvIcon('clock', size: 24),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text('Tayyor bo\'lsin: ${o.readyBy}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          height: 1.35)),
                                ),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _kv('Mijoz ismi', o.customer),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 4),
                                      child: Divider(height: 1, color: _w12),
                                    ),
                                    _kv('Telefon raqami', o.phone),
                                  ]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoCard(
                              child: Center(
                                  child:
                                      _kv('Anjomlar', '${o.packages} ta to\'plam')),
                            ),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 12),
                  // Mijoz izohi — yashil 12% banner (radius 9, p12).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(children: [
                      dlvIcon('message-circle', size: 24, color: _green),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(o.comment,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Taomlar guruhlari — scroll qismi.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (final g in {for (final i in o.items) i.group})
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ItemsGroup(
                              title: g,
                              items:
                                  o.items.where((i) => i.group == g).toList(),
                              editable: o.stage == DStage.yangi,
                              onDelete: (it) =>
                                  setState(() => o.items.remove(it)),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Jami summa (oq 8%, radius 9, p12).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _w08,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(children: [
                      const Text('Jami summa :',
                          style: TextStyle(
                              color: Color(0xFFFAFAFA),
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(_som(o.total),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _actions(o),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Row(children: [
        Text(k, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const Spacer(),
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]);

  // Holatga mos pastki tugmalar (Figma: h44, radius 12, 14px semibold).
  Widget _actions(DOrder o) {
    final mmss = '00:${_accept.toString().padLeft(2, '0')}';
    switch (o.stage) {
      case DStage.yangi:
        return Row(children: [
          Expanded(
              child: _BigButton(
            label: 'Bekor qilish',
            icon: 'x',
            color: _red.withValues(alpha: 0.2),
            textColor: _red,
            onTap: () => _cancel(o),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _BigButton(
            label: 'Qabul qilish  $mmss',
            icon: 'check',
            color: _btnBlue,
            onTap: () => _advance(o),
          )),
        ]);
      case DStage.jarayonda:
        return Row(children: [
          Expanded(
              child: _BigButton(
            label: 'Bekor qilish',
            icon: 'x',
            color: _red.withValues(alpha: 0.2),
            textColor: _red,
            onTap: () => _cancel(o),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _BigButton(
            label: 'Buyurtma Tayyor  $mmss',
            icon: 'check',
            color: _green,
            onTap: () => _advance(o),
          )),
        ]);
      default:
        final line = o.statusLine;
        if (line == null) return const SizedBox.shrink();
        return Text(line,
            style: TextStyle(
                color: o.stage == DStage.bekor ? _red : _green,
                fontSize: 14,
                fontWeight: FontWeight.w600));
    }
  }
}

// ─────────── Kichik vidjetlar ───────────

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 14)),
    );
  }
}

/// O'ng yuqoridagi holat halqasi (Figma: 66×68, ichida oq 12% doira, ikon 24).
class _StatusRing extends StatelessWidget {
  const _StatusRing({required this.stage});
  final DStage stage;
  @override
  Widget build(BuildContext context) {
    final st = _style(stage);
    final done = stage == DStage.yetkazilgan || stage == DStage.bekor;
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 66,
          height: 66,
          child: CircularProgressIndicator(
            value: done ? 1 : 0.4,
            strokeWidth: 2.5,
            backgroundColor: _w12,
            valueColor: AlwaysStoppedAnimation(st.color),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: _w12, shape: BoxShape.circle),
          child: Center(child: dlvIcon(st.icon, size: 24, color: st.color)),
        ),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _w08,
        borderRadius: BorderRadius.circular(9),
      ),
      child: child,
    );
  }
}

/// Taomlar guruhi (Figma: oq 8% karta, radius 9, p12; qatorlar orasida
/// 1px oq 12% chiziq; narx 14px + dots-vertical 24).
class _ItemsGroup extends StatelessWidget {
  const _ItemsGroup({
    required this.title,
    required this.items,
    required this.editable,
    required this.onDelete,
  });
  final String title;
  final List<DItem> items;
  final bool editable;
  final void Function(DItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _w08,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFFAFAFA),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          for (final it in items) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: _w12),
            ),
            Row(children: [
              Text('${it.qty} ta',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(it.note,
                        style: const TextStyle(color: _w42, fontSize: 12)),
                  ],
                ),
              ),
              Text(_som(it.price),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(width: 12),
              if (editable)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: dlvIcon('dots-vertical', size: 24, color: Colors.white),
                  color: const Color(0xFF3A3A3D),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'del') onDelete(it);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        dlvIcon('pencil', size: 24),
                        const SizedBox(width: 4),
                        const Text('O\'zgartirish',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'del',
                      child: Row(children: [
                        dlvIcon('trash', size: 24, color: _red),
                        const SizedBox(width: 4),
                        const Text('O\'chirish',
                            style: TextStyle(color: _red, fontSize: 14)),
                      ]),
                    ),
                  ],
                )
              else
                const SizedBox(width: 24),
            ]),
          ],
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
  });
  final String label;
  final String icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          dlvIcon(icon, size: 20, color: textColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Ustun sarlavhasi (Figma: chevron-up 24 + 18 semibold + rangli badge).
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.stage, required this.count});
  final DStage stage;
  final int count;
  @override
  Widget build(BuildContext context) {
    final st = _style(stage);
    final softBadge = stage == DStage.yetkazilgan;
    return Row(children: [
      dlvIcon('chevron-up', size: 24, color: Colors.white),
      const SizedBox(width: 4),
      Text(st.title,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      const Spacer(),
      Container(
        constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: softBadge ? _green.withValues(alpha: 0.12) : st.color,
          borderRadius: BorderRadius.circular(77),
        ),
        alignment: Alignment.center,
        child: Text('$count',
            style: TextStyle(
                color: softBadge ? _green : Colors.white,
                fontSize: 12,
                height: 1)),
      ),
    ]);
  }
}

/// Buyurtma kartasi — kanbanda ham, detal chap ro'yxatida ham (Figma: oq 8%,
/// radius 8, px12 py8; № 12px, summa 16 semibold, provayder 12px).
/// Bo'sh ustun — Figma matni ("Buyurtmalar hozircha yo'q").
class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.35,
              child: dlvIcon('package', size: 34, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('Buyurtmalar hozircha yo\'q',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Buyurtma kelishi bilan shu yerda ko\'rinadi',
                textAlign: TextAlign.center,
                style: TextStyle(color: _w42, fontSize: 12, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onOpen,
    required this.onAccept,
    required this.onReady,
    this.selected = false,
    this.compact = false,
  });
  final DOrder order;
  final bool selected;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final isBekor = order.stage == DStage.bekor;
    final faded = order.stage == DStage.yetkazilgan && !selected;
    final fg = selected
        ? Colors.white
        : isBekor
            ? _red
            : Colors.white;
    final bg = selected
        ? _chipBlue
        : isBekor
            ? _red.withValues(alpha: 0.08)
            : _w08;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: faded ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('№ ${order.number}',
                            style: TextStyle(color: fg, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(_som(order.total),
                            style: TextStyle(
                                color: fg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        if (order.stage == DStage.yangi) ...[
                          const SizedBox(height: 4),
                          Text(order.provider,
                              style: TextStyle(
                                  color: selected ? Colors.white : _w42,
                                  fontSize: 12)),
                        ] else if (order.statusLine != null &&
                            order.stage != DStage.bekor) ...[
                          const SizedBox(height: 6),
                          Text(order.statusLine!,
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : (order.courier != null
                                          ? _green
                                          : _w42),
                                  fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (order.stage == DStage.yangi && order.minutes != null)
                    _RingTimer(minutes: order.minutes!)
                  else
                    Text(order.provider,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : isBekor
                                    ? _red
                                    : Colors.white,
                            fontSize: 12)),
                ],
              ),
              // Amal tugmasi: Yangi → Qabul qilish, Jarayonda → Tayyor.
              if (order.stage == DStage.yangi) ...[
                const SizedBox(height: 12),
                _SmallButton(
                    label: 'Qabul qilish',
                    icon: 'check',
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : _btnBlue,
                    onTap: onAccept),
              ] else if (order.stage == DStage.jarayonda) ...[
                const SizedBox(height: 12),
                _SmallButton(
                    label: 'Tayyor',
                    icon: 'check',
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : _green.withValues(alpha: 0.12),
                    textColor: selected ? Colors.white : _green,
                    onTap: onReady),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────── Kanban ustuni ───────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.stage,
    required this.orders,
    required this.onOpen,
    required this.onAccept,
    required this.onReady,
  });
  final DStage stage;
  final List<DOrder> orders;
  final void Function(DOrder) onOpen;
  final void Function(DOrder) onAccept;
  final void Function(DOrder) onReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _w08,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(stage: stage, count: orders.length),
          const SizedBox(height: 12),
          Expanded(
            child: orders.isEmpty
                ? const _EmptyColumn()
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _OrderCard(
                      order: orders[i],
                      onOpen: () => onOpen(orders[i]),
                      onAccept: () => onAccept(orders[i]),
                      onReady: () => onReady(orders[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Yangi ustunidagi daqiqa halqasi (Figma: 52px, Rubik Medium).
class _RingTimer extends StatelessWidget {
  const _RingTimer({required this.minutes});
  final int minutes;
  @override
  Widget build(BuildContext context) {
    final v = (minutes.clamp(0, 30)) / 30;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 52,
          height: 52,
          child: CircularProgressIndicator(
            value: v,
            strokeWidth: 3,
            backgroundColor: _w12,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$minutes',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1)),
          const SizedBox(height: 2),
          const Text('Min', style: TextStyle(color: _w42, fontSize: 9)),
        ]),
      ]),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
  });
  final String label;
  final String icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          dlvIcon(icon, size: 20, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

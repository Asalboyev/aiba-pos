import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/pos_chrome.dart';
import '../../domain/entities/payment_method.dart';

/// Chekni bir yoki bir nechta usul bilan yopish oynasi (Figma dark UI).
///
/// Boshlang'ich: "{usul} orqali to'lov" — usul tanlash yo'q (savatdan bosilgan
/// usul), faqat "Olingan summa" + [To'lash] + [Bo'lib to'lash].
/// "Bo'lib to'lash" bosilса — kiritilgan summa qism sifatida qo'shiladi va
/// oyna "Bo'lib to'lash: {qoldi}" holatiga o'tadi: qolgan usullar tanlanadi,
/// [Ortga qaytish] + [To'lash].
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({super.key, required this.total, this.initialMethod});
  final num total;
  final PaymentMethod? initialMethod;

  static Future<List<Payment>?> show(BuildContext context, num total,
      {PaymentMethod? initialMethod}) {
    return showDialog<List<Payment>>(
      context: context,
      builder: (_) => PaymentDialog(total: total, initialMethod: initialMethod),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

/// Bo'lib to'lashda tanlanadigan real usullar (keldi-ketdi bu yerda emas —
/// u VIP comp, alohida oqim).
const _splitMethods = [PaymentMethod.cash, PaymentMethod.card, PaymentMethod.qr];

class _PaymentDialogState extends State<PaymentDialog> {
  final List<Payment> _parts = [];
  late PaymentMethod _method = widget.initialMethod ?? PaymentMethod.cash;
  late final TextEditingController _amount =
      TextEditingController(text: widget.total.round().toString());

  @override
  void initState() {
    super.initState();
    // Har bir bosilgan raqamda qaytim va tugmalar holati qayta hisoblanadi.
    _amount.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountChanged);
    _amount.dispose();
    super.dispose();
  }

  num get _paid => _parts.fold<num>(0, (s, p) => s + p.amount);
  num get _remaining => widget.total - _paid;
  num get _amountValue => num.tryParse(_amount.text.trim()) ?? 0;
  /// Kassir ortiq summa kiritsa — qaytim. To'lov usuli muhim emas: kassir
  /// mijozga qancha qaytarishini darhol ko'rishi kerak.
  num get _change => _amountValue - _remaining;
  bool _used(PaymentMethod m) => _parts.any((p) => p.method == m);
  bool get _inSplit => _parts.isNotEmpty;

  void _setAmountToRemaining() => _amount.text = _remaining.round().toString();

  void _selectMethod(PaymentMethod m) => setState(() {
        _method = m;
        _setAmountToRemaining();
      });

  void _addPart() {
    final amount = _amountValue;
    if (amount <= 0 || amount >= _remaining) return;
    setState(() {
      _parts.add(Payment(_method, amount, label: _method.label));
      // Keyingi bo'sh usulga o'tamiz.
      for (final m in _splitMethods) {
        if (!_used(m)) {
          _method = m;
          break;
        }
      }
      _setAmountToRemaining();
    });
  }

  void _back() {
    if (_parts.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      final removed = _parts.removeLast();
      _method = removed.method;
      _setAmountToRemaining();
    });
  }

  void _finish() {
    Navigator.of(context)
        .pop([..._parts, Payment(_method, _remaining, label: _method.label)]);
  }

  String _assetFor(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'assets/icons/pay_cash.svg',
        PaymentMethod.card => 'assets/icons/pay_card.svg',
        PaymentMethod.qr => 'assets/icons/pay_qr_fill.svg',
        PaymentMethod.keldiKetdi => 'assets/icons/pay_users.svg',
      };

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final canFinish = _remaining > 0 && _amountValue >= _remaining;
    final canAddPart = _amountValue > 0 && _amountValue < _remaining;
    final avail = _splitMethods.where((m) => !_used(m)).toList();

    final title = _inSplit
        ? "Bo'lib to'lash: ${Money.formatSom(_remaining)}"
        : "${_method.label} orqali to'lov";

    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Mishkasiz: Enter — To'lash, Esc — bekor (summa maydoni fokusni
      // yo'qotsa ham ishlaydi).
      child: Focus(
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          if (e.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          // F4 — karta, F5 — naqd, F3 — QR: to'lov usulini almashtirish
          // (savdo ekranidagi klavishalar bilan bir xil).
          PaymentMethod? pick;
          if (e.logicalKey == LogicalKeyboardKey.f5) pick = PaymentMethod.cash;
          if (e.logicalKey == LogicalKeyboardKey.f4) pick = PaymentMethod.card;
          if (e.logicalKey == LogicalKeyboardKey.f3) pick = PaymentMethod.qr;
          if (pick != null && !_used(pick)) {
            setState(() => _method = pick!);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.enter ||
              e.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (canFinish) {
              _finish();
            } else if (canAddPart) {
              _addPart();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 540, maxHeight: screenH - 60),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: PosColors.iconChip,
                      borderRadius: BorderRadius.circular(11)),
                  child: Center(
                    child: _inSplit
                        ? const Icon(Icons.swap_horiz, color: Colors.white, size: 20)
                        : SvgPicture.asset(_assetFor(_method),
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 18),
              // Jami (+ Qoldi split holatida).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0x1F2FBF71),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x332FBF71)),
                ),
                child: Column(children: [
                  _amountRow('Jami:', widget.total, PosColors.green),
                  if (_inSplit) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0x332FBF71)),
                    ),
                    _amountRow('Qoldi:', _remaining, const Color(0xFFF5A623)),
                  ],
                ]),
              ),
              // Qo'shilgan qismlar.
              if (_inSplit) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < _parts.length; i++)
                  _PartRow(
                    iconAsset: _assetFor(_parts[i].method),
                    label: _parts[i].label,
                    amount: _parts[i].amount,
                    onRemove: () => setState(() {
                      final r = _parts.removeAt(i);
                      _method = r.method;
                      _setAmountToRemaining();
                    }),
                  ),
                const SizedBox(height: 6),
                // Qolган summani qaysi usul bilan yopish.
                Row(
                  children: [
                    for (var i = 0; i < avail.length; i++) ...[
                      Expanded(
                        child: _MethodTile(
                          iconAsset: _assetFor(avail[i]),
                          label: avail[i].label,
                          selected: _method == avail[i],
                          onTap: () => _selectMethod(avail[i]),
                        ),
                      ),
                      if (i < avail.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Text('Olingan summa',
                  style: TextStyle(color: PosColors.label, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                // Fizik klaviatura: darhol terish mumkin, Enter → To'lash.
                autofocus: true,
                onSubmitted: (_) {
                  if (_remaining > 0 && _amountValue >= _remaining) {
                    _finish();
                  } else if (_amountValue > 0 && _amountValue < _remaining) {
                    _addPart();
                  }
                },
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: PosColors.field,
                  suffixText: "so'm",
                  suffixStyle: const TextStyle(color: PosColors.muted, fontSize: 15),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PosColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PosColors.blue, width: 1.5),
                  ),
                ),
              ),
              if (_change > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x1F2FBF71),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Qaytim = ',
                        style: TextStyle(color: PosColors.green, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(Money.formatSom(_change),
                        style: const TextStyle(
                            color: PosColors.green, fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              if (_inSplit)
                Row(children: [
                  Expanded(
                    child: _Btn(
                      label: 'Ortga qaytish',
                      icon: Icons.arrow_back,
                      filled: false,
                      onTap: _back,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _Btn(
                      label: 'To\'lash',
                      icon: Icons.check,
                      filled: true,
                      onTap: canFinish ? _finish : null,
                    ),
                  ),
                ])
              else ...[
                _Btn(
                  label: "To'lash",
                  icon: Icons.check,
                  filled: true,
                  onTap: canFinish ? _finish : null,
                ),
                const SizedBox(height: 10),
                _Btn(
                  label: canAddPart
                      ? "Bo'lib to'lash: ${Money.formatSom(_amountValue)}"
                          " · qoldi ${Money.formatSom(_remaining - _amountValue)}"
                      : "Bo'lib to'lash — summani jamidan kam qilib tering",
                  icon: Icons.swap_horiz,
                  filled: false,
                  onTap: canAddPart ? _addPart : null,
                ),
              ],
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Summani tering · Enter — To\'lash · F5 naqd · F4 karta · '
                  'F3 QR · Esc — bekor',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5C626A), fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _amountRow(String label, num amount, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(Money.formatSom(amount),
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      );
}

class _PartRow extends StatelessWidget {
  const _PartRow(
      {required this.iconAsset,
      required this.label,
      required this.amount,
      required this.onRemove});
  final String iconAsset;
  final String label;
  final num amount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PosColors.cardBorder),
        ),
        child: Row(children: [
          SvgPicture.asset(iconAsset,
              width: 20,
              height: 20,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          Text(Money.formatSom(amount),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: PosColors.muted),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.iconAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String iconAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: selected ? PosColors.blue : PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? PosColors.blue : PosColors.cardBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SvgPicture.asset(iconAsset,
              width: 20,
              height: 20,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.label,
      required this.icon,
      required this.filled,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? PosColors.blue : PosColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? PosColors.blue : PosColors.cardBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

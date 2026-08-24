import 'package:flutter/material.dart';

import 'pos_chrome.dart';

/// Ekran ichidagi raqam klaviaturasi — sensorli kassa/tablet uchun asosiy
/// kirish usuli (Windows kassalarda fizik klaviatura bo'lmaydi).
/// 3×4 grid: 1 2 3 / 4 5 6 / 7 8 9 / C 0 ⌫. Katta tugmalar barmoq uchun.
/// [onHide] berilsa yuqorida "klaviaturani yashirish" tugmasi chiqadi.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    this.onHide,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onHide != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Klaviaturani yashirish',
              onPressed: onHide,
              icon: const Icon(Icons.keyboard_hide_outlined, color: Colors.white54),
            ),
          ),
        _row([_key('1'), _key('2'), _key('3')]),
        const SizedBox(height: 8),
        _row([_key('4'), _key('5'), _key('6')]),
        const SizedBox(height: 8),
        _row([_key('7'), _key('8'), _key('9')]),
        const SizedBox(height: 8),
        _row([
          _cmdKey('C', onClear, color: Colors.orange),
          _key('0'),
          _cmdKey('⌫', onBackspace, color: Colors.red),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> tiles) => Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i < tiles.length - 1) const SizedBox(width: 8),
          ],
        ],
      );

  Widget _key(String d) => _KeypadTile(label: d, onTap: () => onDigit(d));

  Widget _cmdKey(String label, VoidCallback onTap, {required Color color}) =>
      _KeypadTile(label: label, onTap: onTap, color: color);
}

class _KeypadTile extends StatefulWidget {
  const _KeypadTile({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<_KeypadTile> createState() => _KeypadTileState();
}

class _KeypadTileState extends State<_KeypadTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? PosColors.blue;
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.94 : 1.0,
      child: Material(
        color: _pressed ? accent.withValues(alpha: 0.18) : PosColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(12),
          splashColor: accent.withValues(alpha: 0.25),
          highlightColor: accent.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pressed ? accent : PosColors.cardBorder,
                width: _pressed ? 1.8 : 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: widget.color ?? Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

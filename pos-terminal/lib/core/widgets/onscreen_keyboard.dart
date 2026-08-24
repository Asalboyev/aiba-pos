import 'package:flutter/material.dart';

/// POS monoblok uchun to'liq kenglikdagi ekran klaviaturasi — Figma "Pos Design"
/// (gboard uslubi): to'q fon, kulrang tugmalar, 1-qatorda ustki raqamlar, 2-qator
/// o'ngida ko'k Enter, Shift, ?123 va bo'sh joy. UZ (lotin) / RU (kirill).
class OnScreenKeyboard extends StatefulWidget {
  const OnScreenKeyboard({
    super.key,
    required this.onChar,
    required this.onBackspace,
    required this.onEnter,
    this.onClear,
  });

  final void Function(String) onChar;
  final VoidCallback onBackspace;

  /// Ko'k → tugma — kiritishни yakunlaydi (klaviaturani yopadi).
  final VoidCallback onEnter;
  final VoidCallback? onClear;

  @override
  State<OnScreenKeyboard> createState() => _OnScreenKeyboardState();
}

enum _Layer { uz, ru, sym }

class _OnScreenKeyboardState extends State<OnScreenKeyboard> {
  _Layer _layer = _Layer.uz;
  _Layer _letterLayer = _Layer.uz; // ABC bosilganda qaytadigan til
  bool _shift = false;

  // Ustki raqamlar 1-qator uchun (gboard kabi).
  static const _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

  static const _uz = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm', "o'", "g'"],
  ];
  static const _ru = [
    ['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з'],
    ['ф', 'ы', 'в', 'а', 'п', 'р', 'о', 'л', 'д'],
    ['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю'],
  ];
  static const _sym = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['@', '#', '№', '_', '&', '-', '+', '(', ')'],
    ['*', '"', "'", ':', ';', '!', '?', '/', '.'],
  ];

  List<List<String>> get _rows => switch (_layer) {
        _Layer.uz => _uz,
        _Layer.ru => _ru,
        _Layer.sym => _sym,
      };

  String _cap(String k) {
    if (!_shift || _layer == _Layer.sym) return k;
    return k.length == 1
        ? k.toUpperCase()
        : (k[0].toUpperCase() + k.substring(1));
  }

  void _tapLetter(String k) {
    widget.onChar(_cap(k));
    if (_shift) setState(() => _shift = false);
  }

  void _toggleLang() => setState(() {
        _letterLayer = _letterLayer == _Layer.uz ? _Layer.ru : _Layer.uz;
        _layer = _letterLayer;
        _shift = false;
      });

  void _toggleSym() => setState(() {
        _layer = _layer == _Layer.sym ? _letterLayer : _Layer.sym;
      });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1B1B1D);
    final isSym = _layer == _Layer.sym;
    // Qator balandligi ekran balandligiga moslashadi (monoblok/kichik modellar)
    // — kassir bemalol tez tersin. Klaviatura ekranning ~52% pastini egallaydi.
    final rowH =
        (MediaQuery.of(context).size.height * 0.115).clamp(80.0, 130.0);
    final fontSize = (rowH * 0.42).clamp(28.0, 44.0);
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1-qator + backspace.
            _KeyRow(height: rowH, children: [
              for (var i = 0; i < _rows[0].length; i++)
                _LetterKey(
                  label: _cap(_rows[0][i]),
                  sup: (!isSym && i < _digits.length) ? _digits[i] : null,
                  fontSize: fontSize,
                  onTap: () => _tapLetter(_rows[0][i]),
                ),
              _SpecialKey(
                flex: 15,
                onTap: widget.onBackspace,
                child: const Icon(Icons.backspace_outlined,
                    color: Colors.white, size: 24),
              ),
            ]),
            // 2-qator + Enter (ko'k).
            _KeyRow(height: rowH, children: [
              const _Gap(flex: 5),
              for (final k in _rows[1])
                _LetterKey(
                    label: _cap(k),
                    fontSize: fontSize,
                    onTap: () => _tapLetter(k)),
              _SpecialKey(
                flex: 16,
                color: const Color(0xFF2277EA),
                onTap: widget.onEnter,
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
              ),
              const _Gap(flex: 5),
            ]),
            // 3-qator: Shift + harflar + Shift/backspace.
            _KeyRow(height: rowH, children: [
              if (!isSym)
                _SpecialKey(
                  flex: 15,
                  color: _shift ? const Color(0xFF3D6DB8) : null,
                  onTap: () => setState(() => _shift = !_shift),
                  child: const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
                )
              else
                _SpecialKey(
                  flex: 15,
                  onTap: widget.onClear ?? () {},
                  child: const Text('Tozalash',
                      style: TextStyle(color: Color(0xFFF5A623), fontSize: 13)),
                ),
              for (final k in _rows[2])
                _LetterKey(
                    label: _cap(k),
                    fontSize: fontSize,
                    onTap: () => _tapLetter(k)),
              _SpecialKey(
                flex: 15,
                onTap: widget.onBackspace,
                child: const Icon(Icons.backspace_outlined,
                    color: Colors.white, size: 22),
              ),
            ]),
            // 4-qator: ?123 | til | bo'sh joy | . | →
            _KeyRow(height: rowH, children: [
              _SpecialKey(
                flex: 16,
                onTap: _toggleSym,
                child: Text(isSym ? 'ABC' : '?123',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              _SpecialKey(
                flex: 13,
                onTap: _toggleLang,
                child: Text(_letterLayer == _Layer.uz ? 'UZ' : 'RU',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              _SpecialKey(
                flex: 44,
                onTap: () => widget.onChar(' '),
                child: const Text('Bo\'sh joy',
                    style: TextStyle(color: Color(0x99FFFFFF), fontSize: 15)),
              ),
              _SpecialKey(
                flex: 13,
                onTap: () => widget.onChar('.'),
                child: const Text('.',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
              _SpecialKey(
                flex: 16,
                color: const Color(0xFF2277EA),
                onTap: widget.onEnter,
                child: const Icon(Icons.keyboard_return, color: Colors.white, size: 22),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Bir qator — bolalar orasida bir xil oraliq, kalitlar `flex` bo'yicha kengayadi.
class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children, this.height = 88});
  final List<Widget> children;
  final double height;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        height: height,
        child: Row(children: children),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap({required this.flex});
  final int flex;
  @override
  Widget build(BuildContext context) => Spacer(flex: flex);
}

class _LetterKey extends StatelessWidget {
  const _LetterKey(
      {required this.label, required this.onTap, this.sup, this.fontSize = 30});
  final String label;
  final String? sup;
  final double fontSize;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 10,
      child: _KeyBox(
        onTap: onTap,
        color: const Color(0xFF48484A),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w400)),
            if (sup != null)
              Positioned(
                top: 4,
                right: 8,
                child: Text(sup!,
                    style: const TextStyle(
                        color: Color(0x8AFFFFFF), fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpecialKey extends StatelessWidget {
  const _SpecialKey({
    required this.flex,
    required this.onTap,
    required this.child,
    this.color,
  });
  final int flex;
  final VoidCallback onTap;
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: _KeyBox(
        onTap: onTap,
        color: color ?? const Color(0xFF2E2E31),
        child: child,
      ),
    );
  }
}

class _KeyBox extends StatelessWidget {
  const _KeyBox(
      {required this.onTap, required this.color, required this.child});
  final VoidCallback onTap;
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Center(child: child),
        ),
      ),
    );
  }
}

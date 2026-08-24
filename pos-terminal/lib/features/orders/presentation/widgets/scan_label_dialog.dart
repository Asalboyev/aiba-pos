import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/pos_chrome.dart';

/// USB barkod skaner uchun DataMatrix (markirovka) kirish dialogi (dark UI).
/// USB skanerlar keyboard-emulator: skanerlaganda matn input'ga yozilib Enter
/// bosiladi — bu "OK" sifatida qabul qilinadi.
class ScanLabelDialog extends StatefulWidget {
  const ScanLabelDialog({super.key, required this.productName});

  final String productName;

  static Future<String?> show(BuildContext context, String productName) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScanLabelDialog(productName: productName),
    );
  }

  @override
  State<ScanLabelDialog> createState() => _ScanLabelDialogState();
}

class _ScanLabelDialogState extends State<ScanLabelDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < 10) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1D22),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        onKeyEvent: (n, e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child:  ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
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
                  child: const Icon(Icons.qr_code_scanner,
                      color: Color(0xFFF5A623), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Markirovka skanerlash',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 16),
              Text(widget.productName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Mahsulot ustidagi kvadrat DataMatrix kodini USB skaner bilan '
                'o\'qing. Skaner avtomatik "Enter" yuboradi.',
                style: TextStyle(color: PosColors.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: PosColors.field,
                  labelText: 'DataMatrix kod',
                  labelStyle: const TextStyle(color: PosColors.muted),
                  hintText: '010478016...',
                  hintStyle: const TextStyle(color: Color(0xFF5C626A)),
                  prefixIcon: const Icon(Icons.qr_code_2, color: PosColors.muted),
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
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: _Btn(
                    label: 'Bekor qilish',
                    filled: false,
                    onTap: () => Navigator.of(context).pop(null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _Btn(
                    label: 'OK',
                    icon: Icons.check,
                    filled: true,
                    onTap: _submit,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(
      {required this.label, required this.filled, required this.onTap, this.icon});
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? PosColors.blue : PosColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? PosColors.blue : PosColors.cardBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

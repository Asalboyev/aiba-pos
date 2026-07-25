import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// USB barkod skaner uchun DataMatrix (markirovka) kirish dialogi.
///
/// USB skanerlar odatda **keyboard emulator** rejimida ishlaydi: skanerlaganda
/// matn (44 belgi atrofida) klaviatura kabi input field'ga yoziladi va Enter
/// bosiladi. Bu dialog shu Enter'ni "OK" sifatida qabul qiladi — kassir hech
/// nima bosmasdan mahsulot avtomatik savatga tushadi.
///
/// Qo'lda yozishga ham imkon bor (skaner ishlamasa yoki test uchun).
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
    // Skaner darrov yozishi uchun input'ga fokus beriladi.
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
    if (text.length < 10) return; // DataMatrix odatda 30+ belgi
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.qr_code_scanner, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('Markirovka skanerlash')),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Mahsulot ustidagi kvadrat DataMatrix kodini USB skaner bilan '
              'o\'qing. Skaner avtomatik "Enter" yuboradi.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'DataMatrix kod',
                hintText: '010478016...',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              // Odatiy skanerdagi Enter/Tab avtomatik `onSubmitted` chaqiradi.
              textInputAction: TextInputAction.done,
              // Barcha belgilar qabul qilinadi (DataMatrix ichida maxsus belgilar bo'ladi).
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Bekor qilish'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('OK'),
        ),
      ],
    );
  }
}

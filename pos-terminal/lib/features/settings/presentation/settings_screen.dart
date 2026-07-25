import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../printing/data/printer_service.dart';
import '../../printing/presentation/printing_providers.dart';

/// Configure the backend base URL, terminal code, and printer (network/USB).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppConfig _config;
  late final TextEditingController _baseUrl;
  late final TextEditingController _terminalCode;
  late final TextEditingController _printerHost;
  late final TextEditingController _printerPort;
  bool _printerUsb = false;
  bool _saved = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _config = ref.read(appConfigProvider);
    _baseUrl = TextEditingController(text: _config.baseUrl);
    _terminalCode = TextEditingController(text: _config.terminalCode);
    _printerHost = TextEditingController(text: _config.printerHost ?? '');
    _printerPort = TextEditingController(text: _config.printerPort.toString());
    _printerUsb = _config.printerUsb;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _terminalCode.dispose();
    _printerHost.dispose();
    _printerPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _config.setBaseUrl(_baseUrl.text);
    await _config.setTerminalCode(_terminalCode.text);
    await _config.setPrinterHost(_printerHost.text);
    await _config.setPrinterPort(
      int.tryParse(_printerPort.text.trim()) ?? AppConfig.defaultPrinterPort,
    );
    await _config.setPrinterUsb(_printerUsb);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sozlamalar saqlandi')),
    );
  }

  Future<void> _testPrint() async {
    await _save();
    setState(() => _testing = true);
    final report = await ref.read(printerServiceProvider).printTest();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(report.message),
      backgroundColor:
          report.outcome == PrintOutcome.printed ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Backend', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: AppConfig.defaultBaseUrl,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _terminalCode,
                decoration: const InputDecoration(
                  labelText: 'Terminal kodi',
                  hintText: 'T1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Printer (ESC/POS)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _printerUsb,
                onChanged: (v) => setState(() => _printerUsb = v),
                title: const Text('USB printer'),
                subtitle: const Text(
                    'Kompyuterga USB orqali ulangan chek printer (IP shart emas)'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _printerHost,
                enabled: !_printerUsb,
                decoration: const InputDecoration(
                  labelText: 'Printer IP (bo\'sh = printer yo\'q)',
                  hintText: '192.168.0.50',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _printerPort,
                enabled: !_printerUsb,
                decoration: const InputDecoration(
                  labelText: 'Printer port',
                  hintText: '9100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _testing ? null : _testPrint,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.receipt_long),
                label: const Text('Test chek chop etish'),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Saqlash'),
              ),
              if (_saved)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Saqlandi ✓',
                      style: TextStyle(color: Colors.green)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

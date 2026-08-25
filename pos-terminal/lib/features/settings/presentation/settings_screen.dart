import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_background.dart';
import '../../printing/data/printer_service.dart';
import '../../printing/presentation/printing_providers.dart';

/// Sozlamalar — Figma "Sozlamalar" dizayni: to'q suv foni, chap navigatsiya
/// paneli (logo + bo'limlar), o'ng yuqorida "Saqlash" tugmasi (o'zgarish
/// bo'lмаса kulrang, bo'lса ko'k). Backend / Fiskal / Printer kartalari.
///
/// Terminal endigina o'rnatilganда bu ekranга login sahifasidan "000" kodi
/// bilan kiriladi (⚙️ tugmasi olib tashlangan). Base URL, terminal kodi va
/// boshqalar to'g'rilanib "Saqlash" bosilganда — sozlamalar saqlanadi va
/// ekran yopilib login sahifasi yangi sozlama bilan ishlay boshlaydi.
class SettingsScreen extends ConsumerStatefulWidget {
  /// [embedded] = true bo'lsa bosh qobiq (HomeShell) ichida tab sifatida
  /// ko'rsatiladi: o'z foni/nav-paneli/avatari/orqaga tugmasi bo'lmaydi.
  const SettingsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

// Dizayn ranglari.
const _panelBg = Color(0xFF111113); // Figma Dark/BG
const _cardBg = Color(0xFF1B1B1C); // Figma Dark/Card
const _cardBorder = Color(0x14FFFFFF);
const _fieldBg = Color(0xFF141519);
const _fieldBorder = Color(0x14FFFFFF);
const _blue = Color(0xFF2277EA); // Figma Dark/Primary
const _green = Color(0xFF2FBF71);
const _muted = Color(0xFF8A9098);
const _label = Color(0xFF9AA0A6);

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppConfig _config;
  late final TextEditingController _baseUrl;
  late final TextEditingController _terminalCode;
  late final TextEditingController _printerHost;
  late final TextEditingController _printerPort;
  late final TextEditingController _printerName;
  late final TextEditingController _communicatorUrl;
  bool _printerUsb = false;
  bool _dirty = false;
  bool _testing = false;
  bool _showToast = false;

  @override
  void initState() {
    super.initState();
    _config = ref.read(appConfigProvider);
    _baseUrl = TextEditingController(text: _config.baseUrl);
    _terminalCode = TextEditingController(text: _config.terminalCode);
    _printerHost = TextEditingController(text: _config.printerHost ?? '');
    _printerPort = TextEditingController(text: _config.printerPort.toString());
    _printerName = TextEditingController(text: _config.printerName);
    _communicatorUrl = TextEditingController(text: _config.communicatorUrl);
    _printerUsb = _config.printerUsb;
    for (final c in [
      _baseUrl,
      _terminalCode,
      _printerHost,
      _printerPort,
      _printerName,
      _communicatorUrl,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _terminalCode.dispose();
    _printerHost.dispose();
    _printerPort.dispose();
    _printerName.dispose();
    _communicatorUrl.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    await _config.setBaseUrl(_baseUrl.text);
    await _config.setTerminalCode(_terminalCode.text);
    await _config.setPrinterHost(_printerHost.text);
    await _config.setPrinterPort(
      int.tryParse(_printerPort.text.trim()) ?? AppConfig.defaultPrinterPort,
    );
    await _config.setPrinterUsb(_printerUsb);
    await _config.setPrinterName(_printerName.text);
    await _config.setCommunicatorUrl(_communicatorUrl.text);
  }

  Future<void> _save() async {
    await _persist();
    if (!mounted) return;
    // Ildizni xabardor qilamiz — birinchi o'rnatiш (setup) bo'lsa login'ga o'tadi.
    ref.read(configVersionProvider.notifier).state++;
    setState(() {
      _dirty = false;
      _showToast = true;
    });
    // Mustaqil (login/setup) rejimда: toast ko'ringach ekran yopilib login
    // yangi sozlama bilan qaytadan ishlaydi. Embedded (bosh qobiq) rejimда
    // ekran yopilmaydi — shunчаki toast ko'rsatiladi.
    if (widget.embedded) return;
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _testPrint() async {
    await _persist();
    setState(() {
      _dirty = false;
      _testing = true;
    });
    final report = await ref.read(printerServiceProvider).printTest();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(report.message),
      backgroundColor:
          report.outcome == PrintOutcome.printed ? _green : Colors.red,
    ));
  }

  Widget _toast() => AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        offset: _showToast ? Offset.zero : const Offset(0, -1.4),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _showToast ? 1 : 0,
          child: _SuccessToast(onClose: () => setState(() => _showToast = false)),
        ),
      );

  Widget _panel(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        child: _content(context),
      );

  @override
  Widget build(BuildContext context) {
    // HomeShell ichida (embedded): faqat panel + toast; fon/rail/avatar
    // qobiqdan keladi.
    if (widget.embedded) {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
            child: _panel(context),
          ),
          Positioned(top: 8, right: 24, child: _toast()),
        ],
      );
    }
    // Mustaqil (login/birinchi o'rnatish): to'liq qobiq + orqaga tugma.
    return Scaffold(
      backgroundColor: const Color(0xFF06090B),
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _NavRail(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                      child: _panel(context),
                    ),
                  ),
                ],
              ),
              const Positioned(top: 10, right: 22, child: _Avatar()),
              Positioned(top: 64, right: 40, child: _toast()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sarlavha + Saqlash.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Orqaga — sozlamalar alohida ochilganда (login yoki bosh
            // ekрандан) chiqish uchun. Tiqilib qolmaslik uchun doim ko'rinadi.
            if (!widget.embedded && Navigator.of(context).canPop()) ...[
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
            ],
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sozlamalar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Bistro POS tizimini sozlash · v1.0.1',
                      style: TextStyle(color: _muted, fontSize: 15)),
                ],
              ),
            ),
            _SaveButton(enabled: _dirty, onTap: _dirty ? _save : null),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _backendCard(),
                    const SizedBox(height: 20),
                    _fiscalCard(),
                  ],
                );
                final right = _printerCard();
                if (!wide) {
                  return Column(children: [left, const SizedBox(height: 20), right]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 20),
                    Expanded(child: right),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _backendCard() {
    return _Card(
      iconAsset: 'assets/icons/set_home.svg',
      title: 'Backend',
      subtitle: 'Kompaniya va filial haqida asosiy ma\'lumotlar',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _Field(
              label: 'Base URL',
              controller: _baseUrl,
              hint: AppConfig.defaultBaseUrl,
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _Field(
              label: 'Terminal kodi',
              controller: _terminalCode,
              hint: 'T1',
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiscalCard() {
    final usb = _printerUsb;
    final desc = usb
        ? (_printerName.text.trim().isEmpty
            ? 'USB printer'
            : _printerName.text.trim())
        : (_printerHost.text.trim().isEmpty
            ? 'USB printer'
            : '${_printerHost.text.trim()} · ${_printerPort.text.trim()}');
    return _Card(
      iconAsset: 'assets/icons/set_receipt.svg',
      title: 'Fiskal modul (E-POS Communicator)',
      subtitle: 'E-POS Communicator shu kompyuterda ishlasa o\'zgartirmang',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            label: 'Comunicator manzili',
            controller: _communicatorUrl,
            hint: AppConfig.defaultCommunicatorUrl,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          // Printer holati + test.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0x142FBF71),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x332FBF71)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: _green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text('Printer ulangan',
                            style: TextStyle(
                                color: _green, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      Text(desc,
                          style: const TextStyle(
                              color: _muted, fontSize: 13)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _testing ? null : _testPrint,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Test chek chop etish'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _printerCard() {
    return _Card(
      iconAsset: 'assets/icons/set_printer.svg',
      title: 'Printer sozlamalari (ESC/POS)',
      subtitle: 'Chek printer ulanishi va chiqarish parametrlari',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('USB printer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: _printerUsb,
                activeThumbColor: Colors.white,
                activeTrackColor: _blue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFF2A2A2E),
                onChanged: (v) => setState(() {
                  _printerUsb = v;
                  _dirty = true;
                }),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Kompyuterga USB orqali ulangan check printer (IP shart emas). '
            'Hech narsa sozlanmasa ham USB printer avtomatik aniqlanadi.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (Platform.isWindows) ...[
            _Field(
              label: 'Printer nomi (Windows USB)',
              controller: _printerName,
              hint: 'Bo\'sh = avtomatik aniqlanadi',
              enabled: _printerUsb,
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _Field(
                  label: 'Printer IP',
                  controller: _printerHost,
                  hint: '192.168.0.50',
                  enabled: !_printerUsb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Field(
                  label: 'Printer Port',
                  controller: _printerPort,
                  hint: '9100',
                  enabled: !_printerUsb,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chap navigatsiya paneli — logo + bo'limlar. Bu setup ekranida bo'limlar
/// faqat ko'rinish uchun (login'ga kirmasdan ishlamaydi); "Sozlamalar" tanlangan.
class _NavRail extends StatelessWidget {
  const _NavRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        children: [
          const SizedBox(height: 16),
          SvgPicture.asset('assets/logo_mark.svg', width: 56, height: 56),
          const SizedBox(height: 34),
          const _NavItem(icon: Icons.shopping_bag_outlined, label: 'Mahsulotlar'),
          const _NavItem(icon: Icons.access_time, label: 'Ish vaqti'),
          const _NavItem(icon: Icons.inventory_2_outlined, label: 'Yetkazib\nberish'),
          const Spacer(),
          const _NavItem(icon: Icons.settings, label: 'Sozlamalar', selected: true),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.selected = false});
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : _muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? const Color(0x1FFFFFFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 11, height: 1.1)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('A',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.check, size: 20, color: enabled ? Colors.white : const Color(0xFF6B7076)),
      label: Text('Saqlash',
          style: TextStyle(
              color: enabled ? Colors.white : const Color(0xFF6B7076),
              fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        backgroundColor: enabled ? _blue : const Color(0xFF23242A),
        disabledBackgroundColor: const Color(0xFF23242A),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String iconAsset;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x3DFFFFFF)),
                ),
                child: Center(
                  child: SvgPicture.asset(iconAsset,
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// Yorliq (tepada) + to'q kirish maydoni — dizayn uslubidagi input.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _label, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: TextStyle(
              color: enabled ? Colors.white : _muted, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: enabled ? _fieldBg : const Color(0xFF161619),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF5C626A)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessToast extends StatelessWidget {
  const _SuccessToast({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: const Color(0xFF12211A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x552FBF71)),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text('Ma\'lumotlari muvaffaqiyatli saqlandi',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Umumiy dizayn ranglari (Figma "Pos Design").
class PosColors {
  // Ranglar Figma "Pos Design" o'zgaruvchilaridan (aniq): Dark/BG #111113,
  // Dark/Card #1B1B1C, Dark/Primary #2277EA.
  static const bg = Color(0xFF06090B);
  static const panel = Color(0xFF111113);
  static const card = Color(0xFF1B1B1C);
  static const cardBorder = Color(0x14FFFFFF);
  static const iconChip = Color(0xFF232329);
  static const field = Color(0xFF141519);
  static const blue = Color(0xFF2277EA);
  static const green = Color(0xFF2FBF71);
  static const red = Color(0xFFE5484D);
  static const muted = Color(0xFF8A9098);
  static const label = Color(0xFF9AA0A6);
}

/// Chap navigatsiya paneli — logo + Mahsulotlar / Ish vaqti / Yetkazib berish,
/// pastda Sozlamalar. Suv fonining ustida turadi (o'z foni yo'q).
class PosNavRail extends StatelessWidget {
  const PosNavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSettings,
    this.settingsSelected = false,
    this.footer,
  });

  /// 0 = Mahsulotlar, 1 = Ish vaqti, 2 = Yetkazib berish. -1 = hech biri.
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;
  final bool settingsSelected;

  /// Pastda ko'rinadigan qo'shimcha tugmalar (Yangilash + Avatar). Ular
  /// avval o'ng yuqorida suzib turardi va kichik oynada qidiruv ustiga
  /// chiqib ketardi — shuning uchun menyuning ichiga ko'chirildi.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        children: [
          const SizedBox(height: 16),
          SvgPicture.asset('assets/logo_mark.svg', width: 52, height: 52),
          const SizedBox(height: 30),
          _NavItem(
            iconAsset: 'assets/icons/nav_products.svg',
            label: 'Mahsulotlar',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            iconAsset: 'assets/icons/nav_shift.svg',
            label: 'Ish vaqti',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            iconAsset: 'assets/icons/nav_delivery.svg',
            label: 'Yetkazib\nberish',
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          const Spacer(),
          if (footer != null) ...[
            footer!,
            const SizedBox(height: 14),
            // Nozik ajratkich — pastki blok menyudan ajralib turadi.
            Container(
              width: 44,
              height: 1,
              color: PosColors.cardBorder,
            ),
            const SizedBox(height: 10),
          ],
          _NavItem(
            iconAsset: 'assets/icons/nav_settings.svg',
            label: 'Sozlamalar',
            selected: settingsSelected,
            onTap: onSettings,
          ),
          const SizedBox(height: 10),
          // Kassir mishka ishlatmaydi — bo'limlar F10 bilan aylanadi.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: PosColors.iconChip,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('F10 ⟳',
                style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
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
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    // Rang: tanlanган — oq; hover — ochroq; oddiy — muted.
    final color = selected
        ? Colors.white
        : (_hover ? const Color(0xFFCBD0D5) : PosColors.muted);
    // Chip foni: tanlanган to'lароq, hover mayin, aks holda shaffof.
    final chipColor = selected
        ? const Color(0x24FFFFFF)
        : (_hover ? const Color(0x14FFFFFF) : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: SvgPicture.asset(
                    widget.iconAsset,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 7),
                Text(widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontSize: 12, height: 1.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O'ng yuqoridagi profil avatari + "Tizimdan chiqish" menyusi.
class PosAvatar extends StatelessWidget {
  const PosAvatar({
    super.key,
    required this.name,
    required this.onLogout,
    this.compact = false,
  });
  final String name;
  final VoidCallback onLogout;

  /// Kichik ekranда (chap menyu ichida) — strelka ko'rsatilmaydi, avatarning
  /// O'ZI bosiladi. Katta ekranда (o'ng yuqorida) Figma ko'rinishi: K + strelka.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF1C1D22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PosColors.cardBorder),
      ),
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(children: [
            const Icon(Icons.person_outline, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Text(name.isEmpty ? 'Xodim' : name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, color: PosColors.red, size: 20),
            SizedBox(width: 10),
            Text('Tizimdan chiqish', style: TextStyle(color: PosColors.red)),
          ]),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // Figma: 135° gradient #22C55E → #059669 + yashil soya.
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22C55E), Color(0xFF059669)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset('assets/icons/chevron_down.svg',
              width: 18,
              height: 18,
              colorFilter:
                  const ColorFilter.mode(Colors.white54, BlendMode.srcIn)),
        ],
      ),
    );
  }
}

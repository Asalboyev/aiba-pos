import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../menu/presentation/providers/menu_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import 'orders_providers.dart';

class SyncState {
  final bool syncing;
  final DateTime? lastSyncAt;
  final int lastSyncedCount;
  final String? message;

  const SyncState({
    this.syncing = false,
    this.lastSyncAt,
    this.lastSyncedCount = 0,
    this.message,
  });

  SyncState copyWith({
    bool? syncing,
    DateTime? lastSyncAt,
    int? lastSyncedCount,
    String? message,
  }) =>
      SyncState(
        syncing: syncing ?? this.syncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
        message: message,
      );
}

/// Drives offline-first sync: refresh the menu (/sync/pull) and push queued
/// orders (/sync/push). Triggered manually and whenever connectivity returns.
class SyncService extends StateNotifier<SyncState> {
  SyncService(this._ref) : super(const SyncState()) {
    // Auto-sync when connectivity is (re)established.
    _ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityStreamProvider,
      (prev, next) {
        next.whenData((results) {
          final online = results.any((r) => r != ConnectivityResult.none);
          if (online) syncAll();
        });
      },
    );
    // Periodic safety-net: adminkada qilingan menyu o'zgarishlari (yangi
    // mahsulot, narx) terminalga qo'lda yangilashsiz yetib kelishi uchun.
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_ref.read(sessionProvider) != null) syncAll();
    });
  }

  final Ref _ref;
  Timer? _periodic;

  @override
  void dispose() {
    _periodic?.cancel();
    super.dispose();
  }

  /// Pull menu + restaurant/receipt settings + push pending orders.
  /// Safe to call repeatedly (idempotent).
  Future<void> syncAll() async {
    if (state.syncing) return;
    state = state.copyWith(syncing: true, message: 'Sinxronlash...');
    try {
      final menuOk = await _ref.read(menuRepositoryProvider).refreshFromServer();
      if (menuOk) {
        _ref.invalidate(categoriesProvider);
        _ref.invalidate(productsProvider);
      }
      // Adminka chek sozlamalarini o'zgartirgan bo'lishi mumkin — cache'ni
      // yangilaymiz. Sinxronlash tugmasi bilan qo'lda ham chaqirsa bo'ladi.
      await _ref.read(sessionProvider.notifier).refreshRestaurant();
      final synced = await _ref.read(ordersRepositoryProvider).syncPending();
      // Fiskal ko'prik: navbatda qolgan cheklarni lokal E-POS Communicator
      // orqali yuborishga urinamiz (epos_terminal rejimi; boshqa rejimlarda
      // server bo'sh ro'yxat qaytaradi — arzon no-op).
      await _ref.read(fiscalBridgeProvider).run();
      _ref.invalidate(recentOrdersProvider);
      _ref.invalidate(unsyncedCountProvider);
      _ref.invalidate(salesSummaryProvider);
      _ref.invalidate(topProductsProvider);
      _ref.invalidate(failedOrdersProvider);
      // Ish vaqti statistikasi (Jami savdo, Naqd, Karta, Buyurtmalar) shu
      // provider'dan o'qiladi — sotuvlar sinxronlangach serverdagi smena
      // jamlari o'zgargan, qayta so'ramasak ekranda nol bo'lib qoladi.
      _ref.invalidate(currentShiftProvider);
      state = state.copyWith(
        syncing: false,
        lastSyncAt: DateTime.now(),
        lastSyncedCount: synced,
        message: synced > 0
            ? '$synced ta buyurtma yuborildi'
            : (menuOk ? 'Menyu va sozlamalar yangilandi' : 'Oflayn'),
      );
    } catch (e) {
      state = state.copyWith(syncing: false, message: 'Sinxronlash xatosi');
    }
  }

  /// Push only pending orders (used right after a checkout).
  Future<void> pushPending() async {
    final synced = await _ref.read(ordersRepositoryProvider).syncPending();
    _ref.invalidate(recentOrdersProvider);
    _ref.invalidate(unsyncedCountProvider);
    _ref.invalidate(currentShiftProvider);
    if (synced > 0) {
      state = state.copyWith(
        lastSyncAt: DateTime.now(),
        lastSyncedCount: synced,
        message: '$synced ta buyurtma yuborildi',
      );
    }
  }
}

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncState>((ref) => SyncService(ref));

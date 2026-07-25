import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/printer_service.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService(ref.watch(appConfigProvider));
});

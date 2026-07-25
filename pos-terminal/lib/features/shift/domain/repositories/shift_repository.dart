import '../entities/shift.dart';

abstract class ShiftRepository {
  /// The currently open shift on this terminal (null if none).
  Future<Shift?> current();

  /// Open a shift with the given opening cash. Returns the open shift.
  Future<Shift> open(num openingCash);

  /// Close a shift. Returns the Z-report (closed shift totals).
  Future<Shift> close({String? shiftId});
}

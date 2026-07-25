import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/shift_remote_datasource.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  ShiftRepositoryImpl(this._remote);
  final ShiftRemoteDataSource _remote;

  @override
  Future<Shift?> current() => _remote.current();

  @override
  Future<Shift> open(num openingCash) => _remote.open(openingCash);

  @override
  Future<Shift> close({String? shiftId}) => _remote.close(shiftId: shiftId);
}

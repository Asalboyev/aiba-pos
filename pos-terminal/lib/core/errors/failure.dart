import 'package:equatable/equatable.dart';

/// A user-facing failure. The presentation layer turns these into messages.
sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Tarmoq xatosi. Internetni tekshiring.']);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Login muvaffaqiyatsiz.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Mahalliy maʼlumot xatosi.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Nomaʼlum xatolik.']);
}

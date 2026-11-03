import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class Correction extends Equatable {
  const Correction(
    this.id,
    this.employee,
    this.name,
    this.mine,
    this.checkIn,
    this.checkOut,
    this.reason,
    this.status,
    this.comment,
  );
  final String id, employee, name, reason, status;
  final bool mine;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? comment;
  @override
  List<Object?> get props => [
    id,
    employee,
    name,
    mine,
    checkIn,
    checkOut,
    reason,
    status,
    comment,
  ];
}

class CorrectionData extends Equatable {
  const CorrectionData(this.requests, this.attendance);
  final List<Correction> requests;
  final List<Choice> attendance;
  @override
  List<Object?> get props => [requests, attendance];
}

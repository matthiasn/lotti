import 'package:equatable/equatable.dart';

/// One value of a series at a point in time: what charts plot and signals
/// aggregate.
class Observation extends Equatable {
  const Observation(this.dateTime, this.value);

  final DateTime dateTime;
  final num value;

  @override
  String toString() {
    return '$dateTime $value';
  }

  @override
  List<Object?> get props => [dateTime, value];
}

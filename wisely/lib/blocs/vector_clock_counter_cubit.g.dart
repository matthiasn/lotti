// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vector_clock_counter_cubit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VectorClockCubitState _$VectorClockCubitStateFromJson(
        Map<String, dynamic> json) =>
    VectorClockCubitState(
      host: json['host'] as String,
      nextAvailableCounter: json['nextAvailableCounter'] as int,
    );

Map<String, dynamic> _$VectorClockCubitStateToJson(
        VectorClockCubitState instance) =>
    <String, dynamic>{
      'host': instance.host,
      'nextAvailableCounter': instance.nextAvailableCounter,
    };

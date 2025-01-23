import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chart_scale_controller.g.dart';

@riverpod
class BarWidthController extends _$BarWidthController {
  @override
  double build() {
    return 1;
  }

  void updateScale(Matrix4 scale) {
    state = scale.row0.x;
  }
}

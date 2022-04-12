import 'dart:math';

import 'package:flutter/material.dart';

double textBodyWidth(BuildContext context) {
  num screenW = MediaQuery.of(context).size.width;
  return min(screenW - 32 - screenW / 8, 700);
}

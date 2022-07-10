Future<void> waitMilliseconds(int ms) async {
  await Future.delayed(Duration(milliseconds: ms), () {});
}

bool isUuid(String? s) {
  return s != null &&
      RegExp(
        r'^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$',
        caseSensitive: false,
      ).hasMatch(s);
}

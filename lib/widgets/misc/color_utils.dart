import 'dart:ui';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();

    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }

    buffer.write(hexString.replaceFirst('#', ''));

    return Color(
      int.parse(
        buffer.toString(),
        radix: 16,
      ),
    );
  }

  String toHex(Color color, {bool leadingHashSign = true}) {
    return '${leadingHashSign ? '#' : ''}'
        '${alpha.toRadixString(16).padLeft(2, '0')}'
        '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
  }
}

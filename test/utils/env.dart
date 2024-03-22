import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<String> getEnv(String key) async {
  await dotenv.load();
  final value = dotenv.env[key];

  if (value == null) {
    throw Exception('Environment variable not defined: $key');
  }

  return value;
}

import 'dart:io';

bool isMobile = !Platform.isMacOS && !Platform.isLinux && !Platform.isWindows;
bool isDesktop = !isMobile;
bool isWindows = Platform.isWindows;
bool isLinux = Platform.isLinux;
bool isMacOS = Platform.isMacOS;

bool isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');

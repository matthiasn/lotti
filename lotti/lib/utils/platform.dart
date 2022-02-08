import 'dart:io';

bool isMobile = !Platform.isMacOS && !Platform.isLinux && !Platform.isWindows;
bool isDesktop = !isMobile;

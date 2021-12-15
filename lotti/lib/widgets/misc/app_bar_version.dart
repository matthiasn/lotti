import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionAppBar extends StatefulWidget with PreferredSizeWidget {
  const VersionAppBar({
    Key? key,
    required this.title,
  });

  final String title;

  @override
  _VersionAppBarState createState() => _VersionAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _VersionAppBarState extends State<VersionAppBar> {
  String version = '';
  String buildNumber = '';

  Future<void> getVersions() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void initState() {
    super.initState();
    getVersions();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.headerBgColor,
      title: Column(
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: AppColors.entryTextColor,
              fontFamily: 'Oswald',
            ),
          ),
          Text(
            'v$version Build $buildNumber',
            style: TextStyle(
              color: AppColors.headerFontColor2,
              fontFamily: 'Oswald',
              fontSize: 10.0,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }
}

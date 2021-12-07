import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class MeasurablesPage extends StatefulWidget {
  const MeasurablesPage({Key? key}) : super(key: key);

  @override
  State<MeasurablesPage> createState() => _MeasurablesPageState();
}

class _MeasurablesPageState extends State<MeasurablesPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Measurables',
          style: TextStyle(
            color: AppColors.entryBgColor,
            fontFamily: 'Oswald',
          ),
        ),
        backgroundColor: AppColors.headerBgColor,
      ),
      backgroundColor: AppColors.entryBgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const <Widget>[],
          ),
        ),
      ),
    );
  }
}

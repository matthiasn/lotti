import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wisely/health/health_service.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late HealthService healthService;

  @override
  void initState() {
    super.initState();
    healthService = HealthService();
  }

  void _import() async {
    healthService.fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton(
              onPressed: _import,
              child: const Text(
                'Import Health Data',
                style: TextStyle(color: CupertinoColors.systemOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

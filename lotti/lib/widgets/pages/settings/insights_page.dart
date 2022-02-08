import 'package:flutter/material.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({Key? key}) : super(key: key);

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final InsightsDb _db = getIt<InsightsDb>();
  late Stream<List<Insight>> stream = _db.watchInsights();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Insight>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Insight>> snapshot,
      ) {
        List<Insight> insights = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.headerBgColor,
            foregroundColor: AppColors.appBarFgColor,
            title: const Text('Logging'),
          ),
          backgroundColor: AppColors.bodyBgColor,
          body: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8.0),
            children: List.generate(
              insights.length,
              (int index) {
                return InsightCard(
                  insight: insights.elementAt(index),
                  index: index,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class InsightCard extends StatelessWidget {
  final Insight insight;
  final int index;

  const InsightCard({
    Key? key,
    required this.insight,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Text(
        '${insight.createdAt.substring(0, 23)}: ${insight.message}',
        style: TextStyle(
          color: AppColors.entryTextColor,
          fontFamily: 'ShareTechMono',
          fontSize: 16.0,
        ),
      ),
    );
  }
}

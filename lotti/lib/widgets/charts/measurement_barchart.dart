import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';

class MeasurementBarChart1 extends StatelessWidget {
  final List<charts.Series<OrdinalSales, String>> seriesList;
  final bool animate;

  const MeasurementBarChart1(this.seriesList, {required this.animate});

  @override
  Widget build(BuildContext context) {
    return charts.BarChart(
      seriesList,
      animate: animate,
    );
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<OrdinalSales, String>> _createSampleData() {
    final data = [
      OrdinalSales('10', 15),
      OrdinalSales('11', 28),
      OrdinalSales('12', 83),
      OrdinalSales('13', 79),
      OrdinalSales('14', 5),
      OrdinalSales('15', 25),
      OrdinalSales('16', 122),
      OrdinalSales('17', 75),
      OrdinalSales('18', 51),
      OrdinalSales('19', 42),
      OrdinalSales('20', 93),
      OrdinalSales('21', 70),
    ];

    return [
      charts.Series<OrdinalSales, String>(
        id: 'Sales',
        colorFn: (OrdinalSales val, _) {
          debugPrint('${val.sales}');
          if (val.sales < 50) {
            return charts.MaterialPalette.red.shadeDefault;
          }
          return charts.MaterialPalette.blue.shadeDefault;
        },
        domainFn: (OrdinalSales sales, _) => sales.year,
        measureFn: (OrdinalSales sales, _) => sales.sales,
        data: data,
      )
    ];
  }
}

/// Sample ordinal data type.
class OrdinalSales {
  final String year;
  final int sales;

  OrdinalSales(this.year, this.sales);
}

class MeasurementBarChart extends StatefulWidget {
  final MeasurableDataType? measurableDataType;

  const MeasurementBarChart({
    Key? key,
    required this.measurableDataType,
  }) : super(key: key);

  @override
  _MeasurementBarChartState createState() => _MeasurementBarChartState();
}

class _MeasurementBarChartState extends State<MeasurementBarChart> {
  final JournalDb _db = getIt<JournalDb>();
  late Stream<List<JournalEntity?>> stream;
  static const duration = Duration(days: 15);

  @override
  void initState() {
    super.initState();
    if (widget.measurableDataType != null) {
      stream = _db.watchMeasurementsByType(
        widget.measurableDataType!.name,
        DateTime.now().subtract(duration),
      );

      stream.listen((event) {
        debugPrint('$event');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          List<JournalEntity?>? measurements = snapshot.data;

          if (measurements == null) {
            return Container();
          }

          return Text(
            'foo',
            style: TextStyle(
              color: AppColors.entryBgColor,
              fontFamily: 'Oswald',
            ),
          );
        });
  }
}

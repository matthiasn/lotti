/// Bar chart example
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final List<charts.Series<OrdinalSales, String>> seriesList;
  final bool animate;

  const SimpleBarChart(this.seriesList, {required this.animate});

  /// Creates a [BarChart] with sample data and no transition.
  factory SimpleBarChart.withSampleData() {
    return SimpleBarChart(
      _createSampleData(),
      // Disable animations for image tests.
      animate: false,
    );
  }

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
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
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

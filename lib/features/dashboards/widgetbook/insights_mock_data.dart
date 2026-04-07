import 'package:flutter/material.dart';

/// Mock data for the Insights widgetbook showcase.
///
/// All values match the Figma design for the Insights main page.
class InsightsMockData {
  InsightsMockData._();

  static const summaryCards = [
    InsightStatCard(
      value: '24.5h',
      label: 'Total tracked',
      delta: '+3.2h',
      deltaPositive: true,
    ),
    InsightStatCard(
      value: '7.2',
      label: 'Avg. productivity',
      delta: '+0.4',
      deltaPositive: true,
    ),
    InsightStatCard(
      value: 'Design',
      label: 'Top category',
      delta: '38%',
    ),
    InsightStatCard(
      value: '12',
      label: 'Interruptions',
      delta: '-5',
      deltaPositive: true,
    ),
  ];

  static const timeDistribution = [
    TimeDistributionEntry(
      category: 'Design',
      hours: 9.3,
      fraction: 0.38,
      percent: '38%',
      weekDelta: '+1.2h',
      weekDeltaPositive: true,
      color: Color(0xFF2BA184),
    ),
    TimeDistributionEntry(
      category: 'Development',
      hours: 6.5,
      fraction: 0.27,
      percent: '27%',
      weekDelta: '-0.8h',
      color: Color(0xFF5973D9),
    ),
    TimeDistributionEntry(
      category: 'Meetings',
      hours: 4.2,
      fraction: 0.17,
      percent: '17%',
      weekDelta: '+0.5h',
      weekDeltaPositive: true,
      color: Color(0xFFF29933),
    ),
    TimeDistributionEntry(
      category: 'Research',
      hours: 2.8,
      fraction: 0.11,
      percent: '11%',
      weekDelta: '+0.3h',
      weekDeltaPositive: true,
      color: Color(0xFFB266BF),
    ),
    TimeDistributionEntry(
      category: 'Admin',
      hours: 1.7,
      fraction: 0.07,
      percent: '7%',
      weekDelta: '-0.2h',
      color: Color(0xFF999999),
    ),
  ];

  static const productivityScores = [
    ProductivityScore(
      label: 'Productivity',
      value: 7.2,
      fraction: 0.72,
      color: Color(0xFF2BA184),
    ),
    ProductivityScore(
      label: 'Energy',
      value: 6.1,
      fraction: 0.61,
      color: Color(0xFFF29933),
    ),
    ProductivityScore(
      label: 'Focus',
      value: 7.8,
      fraction: 0.78,
      color: Color(0xFF5973D9),
    ),
  ];

  static const aiInsight =
      'Your focus ratings are 40% higher before noon. '
      'Consider protecting mornings for deep work.';

  static const interruptionsData = InterruptionsData(
    totalThisWeek: 12,
    perSessionAvg: 1.7,
    mostInterrupted: 'Design',
    deltaPercent: -29,
  );

  static const planningVsReality = [
    PlanVsActualEntry(
      category: 'Design',
      plannedFraction: 0.66,
      actualFraction: 0.77,
      delta: '+1.3h',
      positive: true,
    ),
    PlanVsActualEntry(
      category: 'Development',
      plannedFraction: 0.66,
      actualFraction: 0.54,
      delta: '-1.5h',
      positive: false,
    ),
    PlanVsActualEntry(
      category: 'Meetings',
      plannedFraction: 0.25,
      actualFraction: 0.35,
      delta: '+1.2h',
      positive: true,
    ),
  ];

  static const wellbeingData = WellbeingData(
    avgSession: '2.1h',
    breaksTaken: 6,
    longStreaks: 0,
    aiTip:
        'Great week for breaks! You took regular pauses '
        'and had no marathon sessions. Keep it up.',
  );
}

class InsightStatCard {
  const InsightStatCard({
    required this.value,
    required this.label,
    required this.delta,
    this.deltaPositive,
  });

  final String value;
  final String label;
  final String delta;
  final bool? deltaPositive;
}

class TimeDistributionEntry {
  const TimeDistributionEntry({
    required this.category,
    required this.hours,
    required this.fraction,
    required this.color,
    this.percent = '',
    this.weekDelta = '',
    this.weekDeltaPositive = false,
  });

  final String category;
  final double hours;
  final double fraction;
  final Color color;
  final String percent;
  final String weekDelta;
  final bool weekDeltaPositive;
}

class ProductivityScore {
  const ProductivityScore({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final double value;
  final double fraction;
  final Color color;
}

class InterruptionsData {
  const InterruptionsData({
    required this.totalThisWeek,
    required this.perSessionAvg,
    required this.mostInterrupted,
    required this.deltaPercent,
  });

  final int totalThisWeek;
  final double perSessionAvg;
  final String mostInterrupted;
  final int deltaPercent;
}

class PlanVsActualEntry {
  const PlanVsActualEntry({
    required this.category,
    required this.plannedFraction,
    required this.actualFraction,
    required this.delta,
    required this.positive,
  });

  final String category;
  final double plannedFraction;
  final double actualFraction;
  final String delta;
  final bool positive;
}

class WellbeingData {
  const WellbeingData({
    required this.avgSession,
    required this.breaksTaken,
    required this.longStreaks,
    required this.aiTip,
  });

  final String avgSession;
  final int breaksTaken;
  final int longStreaks;
  final String aiTip;
}

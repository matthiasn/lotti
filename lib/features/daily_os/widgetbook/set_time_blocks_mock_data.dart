import 'package:flutter/material.dart';

/// Mock category data for the Set Time Blocks Widgetbook showcase.
class SetTimeBlocksMockData {
  SetTimeBlocksMockData._();

  static const List<MockCategory> favourites = [
    MockCategory(
      id: 'work',
      name: 'Work',
      color: Color(0xFF9500FF),
      iconColor: Color(0xE09500FF), // rgb(149,0,255) @ 0.88
      icon: Icons.flight,
      isFavourite: true,
      timeBlocks: [
        MockTimeBlock(start: '8:00am', end: '12:00pm'),
        MockTimeBlock(start: '3:00', end: '4:00pm'),
      ],
    ),
    MockCategory(
      id: 'study',
      name: 'Study',
      color: Color(0xFFFFA100),
      iconColor: Color(0xE0FFA100), // rgb(255,161,0) @ 0.88
      icon: Icons.school,
      isFavourite: true,
    ),
    MockCategory(
      id: 'meals',
      name: 'Meals',
      color: Color(0xFF00FFB2),
      iconColor: Color(0xFF00B07B), // rgb(0,176,123) @ 1.0
      icon: Icons.restaurant,
      isFavourite: true,
      timeBlocks: [
        MockTimeBlock(start: '8:00', end: '10:00am'),
      ],
    ),
    MockCategory(
      id: 'exercise',
      name: 'Exercise',
      color: Color(0xFFFF00B7),
      iconColor: Color(0xFFFF00B7), // rgb(255,0,183) @ 1.0
      icon: Icons.fitness_center,
      isFavourite: true,
    ),
  ];

  static const List<MockCategory> otherCategories = [
    MockCategory(
      id: 'leisure',
      name: 'Leisure',
      color: Color(0xFF0004FF),
      iconColor: Color(0xE00004FF), // @ 0.88
      icon: Icons.sentiment_satisfied,
    ),
    MockCategory(
      id: 'commute',
      name: 'Commute',
      color: Color(0xFFEEFF00),
      iconColor: Color(0xE0A8B400), // rgb(168,180,0) @ 0.88
      icon: Icons.directions_car,
      timeBlocks: [
        MockTimeBlock(start: '10:30', end: '11:40am'),
      ],
    ),
    MockCategory(
      id: 'household',
      name: 'Household',
      color: Color(0xFF047ACF),
      iconColor: Color(0xE0047ACF), // @ 0.88
      icon: Icons.door_front_door,
      timeBlocks: [
        MockTimeBlock(start: '1:00', end: '2:00pm'),
      ],
    ),
    MockCategory(
      id: 'holiday',
      name: 'Holiday',
      color: Color(0xFF00FFD0),
      iconColor: Color(0xE000FFD0), // @ 0.88
      icon: Icons.local_bar,
    ),
    MockCategory(
      id: 'leisure2',
      name: 'Leisure',
      color: Color(0xFF0004FF),
      iconColor: Color(0xE00004FF), // @ 0.88
      icon: Icons.sentiment_satisfied,
    ),
  ];
}

class MockCategory {
  const MockCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.iconColor,
    this.isFavourite = false,
    this.timeBlocks = const [],
  });

  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final Color? iconColor;
  final bool isFavourite;
  final List<MockTimeBlock> timeBlocks;

  bool get hasBlocks => timeBlocks.isNotEmpty;
}

class MockTimeBlock {
  const MockTimeBlock({required this.start, required this.end});

  final String start;
  final String end;

  String get label => '$start-$end';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/habit_routes.dart';

void main() {
  test('the habit routes sit under the habits tab root', () {
    expect(habitsRootPath, '/habits');
    expect(habitCreatePath, '/habits/create');
    expect(habitEditPath('habit-1'), '/habits/edit/habit-1');
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisely/blocs/counter_bloc.dart';

void main() {
  group('CounterBloc', () {
    blocTest(
      'emits [] when nothing is added',
      build: () => CounterBloc(),
      expect: () => [],
    );

    blocTest(
      'emits [1] when Increment is added',
      build: () => CounterBloc(),
      act: (CounterBloc bloc) => bloc.add(Increment()),
      expect: () => [1],
    );

    blocTest(
      'emits [0] when Decrement is added',
      build: () => CounterBloc(),
      act: (CounterBloc bloc) => bloc.add(Decrement()),
      expect: () => [0],
    );
  });
}

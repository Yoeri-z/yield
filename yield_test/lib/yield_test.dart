import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yield_state/yield_state.dart';

void testTransform<TState, TArgs>(
  String description, {
  required TState initialState,
  required StateTransform<TState, TArgs> transform,
  required TArgs args,
  required Matcher expectedState,
  required List<Matcher> expectedEffects,
}) {
  test(description, () {
    final transformed = transform(initialState, args);

    expect(transformed.$1, expectedState);
    expect(transformed.$2.unpack(), expectedEffects);
  });
}

void testAsyncTransform<TState, TArgs>(
  String description, {
  required TState initialState,
  required AsyncStateTransform<TState, TArgs> asyncTransform,
  required TArgs args,
  required List<Matcher> expectedStates,
  required List<Matcher> expectedEffects,
}) {
  test(description, () async {
    final yields = await asyncTransform(initialState, args).toList();

    final states = yields.map((e) => e.$1);
    final effects = yields.expand((e) => e.$2.unpack());

    expect(states, expectedStates);
    expect(effects, expectedEffects);
  });
}

void testFlow<TState>(
  String description, {
  required TState initialState,
  required FutureOr<void> Function(StateContainer<TState> container) act,
  required List<Matcher> expectStates,
  required List<Matcher>? expectEffects,
}) {
  test(description, () async {
    final container = StateContainer<TState>(initialState);
    final states = <TState>[];
    final effects = <Effect>[];

    final sub = container.trace.listen((trace) {
      states.add(trace.stateOut);
      effects.addAll(trace.effectOut.unpack());
    });

    await act(container);

    expect(states, expectStates);
    expect(effects, expectEffects);

    await sub.cancel();
    container.dispose();
  });
}

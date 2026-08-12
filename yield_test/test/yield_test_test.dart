import 'package:flutter_test/flutter_test.dart';
import 'package:yield_state/yield_state.dart';
import 'package:yield_test/yield_test.dart';

class EffectA extends Effect {
  const EffectA();
}

class EffectB extends Effect {
  const EffectB();
}

class EffectC extends Effect {
  const EffectC();
}

void main() {
  group('testTransform', () {
    testTransform(
      'calls transform with initial state and args, expects resulting state and effects',
      initialState: 0,
      transform: (state, args) => (state + args, const NoEffect()),
      args: 5,
      expectedState: equals(5),
      expectedEffects: [],
    );

    testTransform(
      'unpacks MultiEffects into individual effects',
      initialState: 'hello',
      transform: (state, args) => (
        state + args,
        const EffectA() + const MultiEffect([EffectB(), EffectC()]),
      ),
      args: ' world',
      expectedState: equals('hello world'),
      expectedEffects: [isA<EffectA>(), isA<EffectB>(), isA<EffectC>()],
    );
  });

  group('testAsyncTransform', () {
    testAsyncTransform(
      'collects multiple yields from async stream',
      initialState: 0,
      asyncTransform: (state, args) async* {
        yield (1, const NoEffect());
        yield (2, const NoEffect());
        yield (3, const NoEffect());
      },
      args: null,
      expectedStates: [equals(1), equals(2), equals(3)],
      expectedEffects: [],
    );

    testAsyncTransform(
      'unpacks nested MultiEffect across yields',
      initialState: 0,
      asyncTransform: (state, args) async* {
        yield (1, const EffectA() + const MultiEffect([EffectB(), EffectC()]));
        yield (2, const NoEffect());
      },
      args: null,
      expectedStates: [equals(1), equals(2)],
      expectedEffects: [isA<EffectA>(), isA<EffectB>(), isA<EffectC>()],
    );

    testAsyncTransform(
      'returns empty lists for empty stream',
      initialState: 0,
      asyncTransform: (state, args) => Stream.empty(),
      args: null,
      expectedStates: [],
      expectedEffects: [],
    );
  });

  group('testFlow', () {
    testFlow(
      'records state transitions from container.transform calls',
      initialState: 0,
      act: (container) async {
        container.transform<int>(
          (state, args) => (state + args, const NoEffect()),
          10,
        );
      },
      expectStates: [equals(10)],
      expectEffects: [],
    );

    testFlow<int>(
      'unpacks MultiEffect into individual effects',
      initialState: 0,
      act: (container) async {
        container.transform<int>(
          (state, args) => (
            state,
            const EffectA() + const MultiEffect([EffectB(), EffectC()]),
          ),
          0,
        );
      },
      expectStates: [equals(0)],
      expectEffects: [isA<EffectA>(), isA<EffectB>(), isA<EffectC>()],
    );

    testFlow<int>(
      'records multiple transitions in order',
      initialState: 0,
      act: (container) async {
        container.transform(
          (state, args) => (state + 1, const NoEffect()),
          null,
        );
        container.transform(
          (state, args) => (state + 1, const NoEffect()),
          null,
        );
        container.transform(
          (state, args) => (state + 1, const NoEffect()),
          null,
        );
      },
      expectStates: [equals(1), equals(2), equals(3)],
      expectEffects: [],
    );
  });
}

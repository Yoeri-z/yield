import 'package:flutter_test/flutter_test.dart';
import 'package:yield_state/src/state/container.dart';
import 'package:yield_state/src/state/effect.dart';

class EffectA extends Effect {
  const EffectA();
}

class EffectB extends Effect {
  const EffectB();
}

class LogEffect extends Effect {
  const LogEffect(this.message);
  final String message;
}

void main() {
  tearDown(() {
    StateContainer.effectDispatcher = null;
  });

  group('StateContainer', () {
    test('holds initial state', () {
      final container = StateContainer<int>(42);
      expect(container.value, 42);
      container.dispose();
    });

    test('transform updates state', () {
      final container = StateContainer<int>(0);
      container.transform<int>(
        (state, args) => (state + args, const NoEffect()),
        10,
      );
      expect(container.value, 10);
      container.dispose();
    });

    test('transform chains state across calls', () {
      final container = StateContainer<int>(0);
      container.transform<void>(
        (state, _) => (state + 1, const NoEffect()),
        null,
      );
      container.transform<void>(
        (state, _) => (state + 1, const NoEffect()),
        null,
      );
      container.transform<void>(
        (state, _) => (state + 1, const NoEffect()),
        null,
      );
      expect(container.value, 3);
      container.dispose();
    });

    test('transform dispatches effect to dispatcher', () {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);
      container.addDispatcher((effect) {
        dispatched.add(effect);
        return effect;
      });

      container.transform<void>((_, _) => (0, const EffectA()), null);

      expect(dispatched, [isA<EffectA>()]);
      container.dispose();
    });

    test('transform does not dispatch NoEffect', () {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);
      container.addDispatcher((effect) {
        dispatched.add(effect);
        return effect;
      });

      container.transform<void>((_, _) => (0, const NoEffect()), null);

      expect(dispatched, isEmpty);
      container.dispose();
    });

    test('transform unpacks MultiEffect and dispatches each leaf', () {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);
      container.addDispatcher((effect) {
        dispatched.add(effect);
        return effect;
      });

      container.transform<void>(
        (_, _) => (0, const EffectA() + const EffectB()),
        null,
      );

      expect(dispatched, [isA<EffectA>(), isA<EffectB>()]);
      container.dispose();
    });
  });

  group('addDispatcher', () {
    test('inserts dispatcher at front of chain', () {
      final order = <String>[];
      final container = StateContainer<int>(0);

      container.addDispatcher((effect) {
        order.add('first');
        return effect;
      });
      container.addDispatcher((effect) {
        order.add('second');
        return effect;
      });

      container.transform<void>((_, _) => (0, const EffectA()), null);

      // addDispatcher inserts at index 0, so second runs first
      expect(order, ['second', 'first']);
      container.dispose();
    });

    test('null dispatcher is ignored', () {
      final container = StateContainer<int>(0);
      container.addDispatcher(null);

      // Should not throw
      container.transform<void>((_, _) => (0, const NoEffect()), null);
      container.dispose();
    });

    test('dispatcher returning null stops propagation', () {
      final order = <String>[];
      final container = StateContainer<int>(0);

      container.addDispatcher((effect) {
        order.add('first');
        return effect;
      });
      container.addDispatcher((effect) {
        order.add('stop');
        return null; // stop chain
      });

      container.transform<void>((_, _) => (0, const EffectA()), null);

      // 'stop' is inserted at front, runs first, returns null → chain stops
      expect(order, ['stop']);
      container.dispose();
    });

    test('dispatcher can modify effect', () {
      final container = StateContainer<int>(0);
      Effect? received;
      container.addDispatcher((effect) {
        received = effect;
        return effect;
      });

      container.transform<void>((_, _) => (0, const EffectA()), null);

      expect(received, isA<EffectA>());
      container.dispose();
    });
  });

  group('removeDispatcher', () {
    test('removes a registered dispatcher', () {
      final dispatched = <Effect>[];
      Effect dispatcher(Effect effect) {
        dispatched.add(effect);
        return effect;
      }
      final container = StateContainer<int>(0);
      container.addDispatcher(dispatcher);

      container.transform<void>((_, _) => (0, const EffectA()), null);
      expect(dispatched, [isA<EffectA>()]);

      container.removeDispatcher(dispatcher);
      container.transform<void>((_, _) => (0, const EffectA()), null);

      // Still only the first dispatch — second transform fired no dispatcher
      expect(dispatched, [isA<EffectA>()]);
      container.dispose();
    });

    test('null dispatcher is ignored', () {
      final container = StateContainer<int>(0);
      // Should not throw
      container.removeDispatcher(null);
      container.dispose();
    });

    test('removing a dispatcher not in the chain is a no-op', () {
      final container = StateContainer<int>(0);
      Effect dispatcher(Effect effect) => effect;

      // Removing one that was never added — must not throw
      container.removeDispatcher(dispatcher);
      container.dispose();
    });

    test('removing one dispatcher leaves others in the chain', () {
      final order = <String>[];
      Effect first(Effect effect) {
        order.add('first');
        return effect;
      }
      Effect second(Effect effect) {
        order.add('second');
        return effect;
      }
      final container = StateContainer<int>(0);
      container.addDispatcher(first);
      container.addDispatcher(second);

      container.removeDispatcher(first);

      container.transform<void>((_, _) => (0, const EffectA()), null);

      // first was at the back, second still at front and runs
      expect(order, ['second']);
      container.dispose();
    });
  });

  group('transformAsync', () {
    test('processes multiple yields from stream', () async {
      final container = StateContainer<int>(0);
      await container.transformAsync<void>((state, _) async* {
        yield (1, const NoEffect());
        yield (2, const NoEffect());
        yield (3, const NoEffect());
      }, null);

      expect(container.value, 3);
      container.dispose();
    });

    test('dispatches effect for each yield', () async {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);
      container.addDispatcher((effect) {
        dispatched.add(effect);
        return effect;
      });

      await container.transformAsync<void>((state, _) async* {
        yield (1, const EffectA());
        yield (2, const EffectB());
      }, null);

      expect(dispatched, [isA<EffectA>(), isA<EffectB>()]);
      container.dispose();
    });

    test('empty stream does not change state', () async {
      final container = StateContainer<int>(42);
      await container.transformAsync<void>((state, _) async* {}, null);

      expect(container.value, 42);
      container.dispose();
    });
  });

  group('trace stream', () {
    test('emits Trace for each transform', () async {
      final container = StateContainer<int>(0);
      final traces = <Trace<int>>[];

      final sub = container.trace.listen(traces.add);

      container.transform<void>(
        (state, _) => (state + 1, const NoEffect()),
        null,
      );
      container.transform<void>(
        (state, _) => (state + 1, const NoEffect()),
        null,
      );

      await Future.microtask(() {});

      expect(traces, hasLength(2));
      expect(traces[0].stateIn, 0);
      expect(traces[0].stateOut, 1);
      expect(traces[1].stateIn, 1);
      expect(traces[1].stateOut, 2);

      await sub.cancel();
      container.dispose();
    });

    test('emits Trace for each async yield', () async {
      final container = StateContainer<int>(0);
      final traces = <Trace<int>>[];

      final sub = container.trace.listen(traces.add);

      await container.transformAsync<void>((state, _) async* {
        yield (1, const NoEffect());
        yield (2, const NoEffect());
      }, null);

      expect(traces, hasLength(2));
      expect(traces[0].stateIn, 0);
      expect(traces[0].stateOut, 1);
      expect(traces[1].stateIn, 1);
      expect(traces[1].stateOut, 2);

      await sub.cancel();
      container.dispose();
    });

    test('Trace includes effect and runId', () async {
      final container = StateContainer<int>(0);
      Trace<int>? firstTrace;

      final sub = container.trace.listen((trace) {
        firstTrace ??= trace;
      });

      container.transform<void>((_, _) => (0, const EffectA()), null);

      await Future.microtask(() {});

      expect(firstTrace, isNotNull);
      expect(firstTrace!.effectOut, isA<EffectA>());
      expect(firstTrace!.runId, 1);

      await sub.cancel();
      container.dispose();
    });

    test('runId increments across transforms', () async {
      final container = StateContainer<int>(0);
      final traces = <Trace<int>>[];

      final sub = container.trace.listen(traces.add);

      container.transform<void>((state, _) => (state, const NoEffect()), null);
      container.transform<void>((state, _) => (state, const NoEffect()), null);
      container.transform<void>((state, _) => (state, const NoEffect()), null);

      await Future.microtask(() {});

      expect(traces[0].runId, 1);
      expect(traces[1].runId, 2);
      expect(traces[2].runId, 3);

      await sub.cancel();
      container.dispose();
    });
  });

  group('effectDispatcher (global)', () {
    test('applied to new containers', () {
      final dispatched = <Effect>[];
      StateContainer.effectDispatcher = (effect) {
        dispatched.add(effect);
        return effect;
      };

      final container = StateContainer<int>(0);
      container.transform<void>((_, _) => (0, const EffectA()), null);

      expect(dispatched, [isA<EffectA>()]);
      container.dispose();
    });

    test('does not affect containers created before assignment', () {
      final container = StateContainer<int>(0);
      final dispatched = <Effect>[];
      container.addDispatcher((effect) {
        dispatched.add(effect);
        return effect;
      });

      StateContainer.effectDispatcher = (effect) => null;

      container.transform<void>((_, _) => (0, const EffectA()), null);

      // Only the instance dispatcher fires; global was set after creation
      expect(dispatched, [isA<EffectA>()]);
      container.dispose();
    });
  });

  group('dispose', () {
    test('clears dispatchers', () {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);
      container.addDispatcher((effect) {
        dispatched.add(effect);
        return effect;
      });

      container.dispose();
      container.transform<void>((_, _) => (0, const EffectA()), null);

      expect(dispatched, isEmpty);
    });

    test('closes trace stream', () {
      final container = StateContainer<int>(0);
      final traces = <Trace<int>>[];

      final sub = container.trace.listen(traces.add);
      container.dispose();

      // Adding to a closed controller should not throw (broadcast controllers ignore)
      // But the stream should be closed, so no new events arrive
      expect(traces, isEmpty);
      sub.cancel();
    });
  });
}

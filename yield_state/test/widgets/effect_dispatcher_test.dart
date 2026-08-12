import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yield_state/src/state/container.dart';
import 'package:yield_state/src/state/effect.dart';
import 'package:yield_state/src/widgets/consumers.dart';
import 'package:yield_state/src/widgets/providers.dart';

class EffectA extends Effect {
  const EffectA();
}

void main() {
  tearDown(() {
    StateContainer.effectDispatcher = null;
  });

  group('EffectDispatcher', () {
    testWidgets('registers dispatcher on initial build', (tester) async {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);

      await tester.pumpWidget(
        StateProvider<int>.value(
          value: container,
          child: EffectDispatcher<int>(
            dispatcher: (effect) {
              dispatched.add(effect);
              return effect;
            },
            child: const SizedBox(),
          ),
        ),
      );

      container.transform<void>((_, _) => (0, const EffectA()), null);

      expect(dispatched, [isA<EffectA>()]);
      container.dispose();
    });

    testWidgets('removes dispatcher when widget is removed', (tester) async {
      final dispatched = <Effect>[];
      final container = StateContainer<int>(0);

      await tester.pumpWidget(
        StateProvider<int>.value(
          value: container,
          child: EffectDispatcher<int>(
            dispatcher: (effect) {
              dispatched.add(effect);
              return effect;
            },
            child: const SizedBox(),
          ),
        ),
      );

      container.transform<void>((_, _) => (0, const EffectA()), null);
      expect(dispatched, [isA<EffectA>()]);

      // Remove the widget from the tree — dispatcher should be removed
      await tester.pumpWidget(
        StateProvider<int>.value(
          value: container,
          child: const SizedBox(),
        ),
      );

      dispatched.clear();
      container.transform<void>((_, _) => (0, const EffectA()), null);

      expect(dispatched, isEmpty);
      container.dispose();
    });

    testWidgets('swaps dispatcher when container is replaced', (tester) async {
      final dispatchedForContainer1 = <Effect>[];
      final dispatchedForContainer2 = <Effect>[];
      final container1 = StateContainer<int>(0);
      final container2 = StateContainer<int>(0);

      var useFirst = true;

      Widget build(_) {
        final container = useFirst ? container1 : container2;
        return StateProvider<int>.value(
          value: container,
          child: EffectDispatcher<int>(
            dispatcher: (effect) {
              (useFirst ? dispatchedForContainer1 : dispatchedForContainer2)
                  .add(effect);
              return effect;
            },
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(build(null));

      container1.transform<void>((_, _) => (0, const EffectA()), null);
      expect(dispatchedForContainer1, [isA<EffectA>()]);

      // Swap which container is provided — the dispatcher must detach/reattach
      useFirst = false;
      await tester.pumpWidget(build(null));

      container1.transform<void>((_, _) => (0, const EffectA()), null);
      container2.transform<void>((_, _) => (0, const EffectA()), null);

      // container1 no longer fires; container2 does
      expect(dispatchedForContainer1, [isA<EffectA>()]);
      expect(dispatchedForContainer2, [isA<EffectA>()]);

      container1.dispose();
      container2.dispose();
    });

    testWidgets('passes child through unchanged', (tester) async {
      const key = ValueKey<String>('child-marker');
      final container = StateContainer<int>(0);

      await tester.pumpWidget(
        StateProvider<int>.value(
          value: container,
          child: EffectDispatcher<int>(
            dispatcher: (effect) => effect,
            child: const SizedBox(key: key),
          ),
        ),
      );

      expect(find.byKey(key), findsOneWidget);
      container.dispose();
    });
  });
}

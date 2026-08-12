import 'package:flutter_test/flutter_test.dart';
import 'package:yield_state/src/state/effect.dart';

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
  test('MultiEffect is equal by content', () {
    expect(
      MultiEffect([const EffectA()]),
      equals(MultiEffect([const EffectA()])),
    );
  });

  test('Effects combine into a flat MultiEffect', () {
    expect(
      const EffectA() + const EffectB() + const EffectC(),
      equals(MultiEffect([const EffectA(), const EffectB(), const EffectC()])),
    );
  });

  test('NoEffect is dropped when combined', () {
    expect(
      const EffectA() + const NoEffect(),
      equals(MultiEffect([const EffectA()])),
    );
  });

  test('MultiEffect flattens nested MultiEffects', () {
    final inner = MultiEffect([const EffectA(), const EffectB()]);
    expect(
      inner + const EffectC(),
      equals(MultiEffect([const EffectA(), const EffectB(), const EffectC()])),
    );
  });
}

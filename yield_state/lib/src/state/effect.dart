import 'package:equatable/equatable.dart';

/// Base class for all side-effects.
///
/// Extend this to create domain-specific effects (e.g. `ShowToast`, `Navigate`).
/// Effects are produced by state transforms and dispatched through the container's
/// dispatcher chain.
///
/// Combine multiple effects with `+`:
/// ```dart
/// final combined = ShowToast('hi') + Navigate('/home');
/// ```
///
/// Override [unpack] to control how your effect flattens when combined.
abstract class Effect {
  const Effect();

  /// Combines this effect with [other] into a [MultiEffect].
  MultiEffect operator +(Effect other) => and(other);

  /// Combines this effect with [other] into a [MultiEffect].
  ///
  /// Both effects are unpacked via [unpack] before merging, so nested
  /// [MultiEffect]s are flattened automatically.
  MultiEffect and(Effect other) {
    return MultiEffect([...unpack(), ...other.unpack()]);
  }

  /// Flattens this effect into a list of leaf effects.
  ///
  /// The default returns `this` as a single-element list. Override to return
  /// an empty list to silently drop the effect when combined (see [NoEffect]),
  /// or return multiple effects to expand into a [MultiEffect].
  List<Effect> unpack() {
    return [this];
  }
}

/// Sentinel effect indicating nothing should be dispatched.
///
/// [unpack] returns an empty list, so combining with [NoEffect] is a no-op.
class NoEffect extends Effect with Equatable {
  const NoEffect();

  @override
  List<Object?> get props => const [];

  /// Returns an empty list — [NoEffect] is silently dropped when combined.
  @override
  List<Effect> unpack() {
    return const [];
  }
}

/// Wraps a list of effects into a single composite effect.
///
/// When combined with another [Effect], nested [MultiEffect]s are flattened
/// via [unpack] into a single list.
class MultiEffect extends Effect with Equatable {
  const MultiEffect(this.effects);

  /// The individual effects in this composite.
  final List<Effect> effects;

  @override
  List<Object?> get props => [...effects];

  /// Returns the inner [effects] list, flattening this composite.
  @override
  List<Effect> unpack() {
    return [...effects];
  }
}

import 'effect.dart';

/// A `(nextState, effect)` record produced by a state transform function.
///
/// Every state transition must return exactly this shape: the new state
/// and a single [Effect] to dispatch (use [NoEffect] when there is none).
typedef Yield<TState> = (TState, Effect);

/// Synchronous state transform — receives current state and arguments, returns a single [Yield].
typedef StateTransform<TState, TArgs> = Yield<TState> Function(TState, TArgs);

/// Asynchronous state transform — receives current state and arguments, emits a [Yield] per
/// state transition via a [Stream].
typedef AsyncStateTransform<TState, TArgs> =
    Stream<Yield<TState>> Function(TState, TArgs);

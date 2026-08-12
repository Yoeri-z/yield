import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yield_state/src/state/effect.dart';
import 'package:yield_state/src/state/yield.dart';

/// Diagnostic record emitted to the [StateContainer.trace] stream.
///
/// Contains the full context of a single state transition: input state,
/// output state, the effect produced, and which transform produced it.
typedef Trace<TState> = ({
  int runId,
  TState stateIn,
  TState stateOut,
  Effect effectOut,
  Object func,
  Object? args,
});

/// A dispatcher intercepts and handles effects.
///
/// Must return the (possibly modified) effect if it should propagate to
/// the next dispatcher, or `null` to stop the chain.
typedef Dispatcher = Effect? Function(Effect effect);

/// Core state container backed by Flutter's [ValueNotifier].
///
/// Holds a value of type [TState] and exposes [transform] / [transformAsync]
/// to apply state transitions produced by transform functions. Effects are
/// dispatched through a chain of [Dispatcher]s.
///
/// ```dart
/// final container = StateContainer<int>(0);
/// container.transform((state, args) => (state + 1, NoEffect()), 0);
/// print(container.value); // 1
/// ```
class StateContainer<TState> extends ValueNotifier<TState> {
  /// Creates a container with [initialState].
  StateContainer(super._value);

  /// Global dispatcher applied to every new [StateContainer].
  static Dispatcher? effectDispatcher;

  final List<Dispatcher> _dispatchers = [?effectDispatcher];

  /// Lazy broadcast stream that emits [Trace] records for each transition.
  ///
  /// The stream is only created on first access; no overhead if unused.
  Stream<Trace<TState>> get trace {
    _traceController ??= StreamController.broadcast(sync: true);

    return _traceController!.stream;
  }

  StreamController<Trace<TState>>? _traceController;
  int _nextRunId = 0;

  void _dispatchEffect(Effect effect) {
    switch (effect) {
      case NoEffect():
        break;
      case MultiEffect(:final effects):
        for (final e in effects) {
          _dispatchEffect(e);
        }
      default:
        for (final dispatcher in _dispatchers) {
          final propegated = dispatcher(effect);
          if (propegated == null) break;
          effect = propegated;
        }
    }
  }

  /// Inserts [dispatcher] at the front of the dispatch chain.
  ///
  /// Pass `null` to skip adding a dispatcher.
  void addDispatcher(Dispatcher? dispatcher) {
    if (dispatcher == null) return;
    _dispatchers.insert(0, dispatcher);
  }

  /// Removes [dispatcher] from the dispatch chain.
  void removeDispatcher(Dispatcher? dispatcher) {
    if (dispatcher == null) return;
    _dispatchers.remove(dispatcher);
  }

  /// Applies a synchronous transform: runs [transform] with current state and [args],
  /// sets the new value, and dispatches the resulting effect.
  void transform<TArgs extends Object?>(
    StateTransform<TState, TArgs> transform,
    TArgs args,
  ) {
    final runId = ++_nextRunId;
    final startState = value;

    final (nextState, effect) = transform(startState, args);

    _traceController?.add((
      runId: runId,
      stateIn: startState,
      stateOut: nextState,
      effectOut: effect,
      func: transform,
      args: args,
    ));

    value = nextState;
    _dispatchEffect(effect);
  }

  /// Applies an asynchronous transform: runs [transform] with current state and [args],
  /// awaiting each emitted [Yield] to update state and dispatch effects.
  ///
  /// Useful for flows that produce multiple transitions (e.g. loading → loaded).
  Future<void> transformAsync<TArgs extends Object?>(
    AsyncStateTransform<TState, TArgs> transform,
    TArgs args,
  ) async {
    final runId = ++_nextRunId;
    final stream = transform(value, args);
    await for (final (nextState, effect) in stream) {
      final stateIn = value;

      _traceController?.add((
        runId: runId,
        stateIn: stateIn,
        stateOut: nextState,
        effectOut: effect,
        func: transform,
        args: args,
      ));

      value = nextState;
      _dispatchEffect(effect);
    }
  }

  /// Cleans up dispatchers and closes the trace stream.
  @override
  void dispose() {
    _dispatchers.clear();
    _traceController?.close();
    super.dispose();
  }
}

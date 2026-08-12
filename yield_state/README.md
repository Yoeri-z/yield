# yield_state

Return-driven state management for Flutter built around the
**Correctness-by-Construction** principle.

Every state transition is a pure function that returns a `(State, Effect)` tuple.
Business logic never mutates state directly — it just describes what should
happen. Effects are dispatched through a chain of handlers, keeping
side-effects fully decoupled from state updates.

This makes code trivially testable (the transform is a pure function) and
IDE-friendly (the compiler enforces the return shape), which is ideal for
AI-assisted development.

---

## Example

```dart
import 'package:flutter/material.dart';
import 'package:yield_state/yield_state.dart';

// ── State ────────────────────────────────────────────────────────────────

sealed class CounterState {
  const CounterState();
}

class CounterInitial extends CounterState {
  const CounterInitial();
}

class CounterLoaded extends CounterState {
  const CounterLoaded(this.value);
  final int value;
}

// ── Effects ──────────────────────────────────────────────────────────────

sealed class CounterEffect extends Effect {
  const CounterEffect();
}

class ShowSnackbar extends CounterEffect {
  const ShowSnackbar(this.message);
  final String message;
}

// ── Transforms ───────────────────────────────────────────────────────────

(CounterState, Effect) increment(CounterState state, _) {
  final current = switch (state) { CounterLoaded(:final value) => value, _ => 0 };
  return (CounterLoaded(current + 1), const NoEffect());
}

(CounterState, Effect) decrement(CounterState state, _) {
  final current = switch (state) { CounterLoaded(:final value) => value, _ => 0 };
  final next = current - 1;
  return (
    CounterLoaded(next),
    ShowSnackbar(next < 0 ? 'Negative!' : 'OK'),
  );
}

// ── App ──────────────────────────────────────────────────────────────────

void main() {
  runApp(
    StateProvider<CounterState>(
      create: (_) => const CounterInitial(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: StateWatcher<CounterState>(
            builder: (context, state, _) {
              final value = switch (state) {
                CounterLoaded(:final value) => value,
                _ => 0,
              };
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$value', style: const TextStyle(fontSize: 48)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () =>
                            context.read<StateContainer<CounterState>>().transform(decrement, null),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        onPressed: () =>
                            context.read<StateContainer<CounterState>>().transform(increment, null),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

---

## API Reference

### `Yield<TState>`

```dart
typedef Yield<TState> = (TState, Effect);
```

A `(nextState, effect)` record. Every state transform must return exactly this shape.

### `StateTransform<TState, TArgs>`

```dart
typedef StateTransform<TState, TArgs> = Yield<TState> Function(TState, TArgs);
```

Synchronous state transform — receives current state and arguments, returns
a single `Yield`.

### `AsyncStateTransform<TState, TArgs>`

```dart
typedef AsyncStateTransform<TState, TArgs> = Stream<Yield<TState>> Function(TState, TArgs);
```

Asynchronous state transform — emits multiple `Yield`s via a `Stream` for
multi-step flows (e.g. loading → loaded).

---

### `Effect`

```dart
abstract class Effect {
  const Effect();
  MultiEffect operator +(Effect other);
  MultiEffect and(Effect other);
  List<Effect> unpack();
}
```

Base class for side-effects. Extend it to create domain-specific effects.
Combine with `+`:

```dart
final combined = ShowToast('hi') + Navigate('/home');
```

Override [unpack] to control how your effect flattens when combined.

### `NoEffect`

```dart
class NoEffect extends Effect { const NoEffect(); }
```

Sentinel — indicates no effect should be dispatched. Returns an empty list
from `unpack()`, so it is silently dropped when combined with other effects.

### `MultiEffect`

```dart
class MultiEffect extends Effect {
  const MultiEffect(this.effects);
  final List<Effect> effects;
}
```

Wraps multiple effects into one. [unpack] returns the inner list, flattening
nested `MultiEffect`s automatically.

---

### `StateContainer<TState>`

```dart
class StateContainer<TState> extends ValueNotifier<TState> {
  StateContainer(TState value, {void Function(StateContainer<TState> container)? onCreate});
  static Dispatcher? effectDispatcher;

  void addDispatcher(Dispatcher? dispatcher);
  void removeDispatcher(Dispatcher? dispatcher);
  void transform<TArgs>(StateTransform<TState, TArgs> transform, TArgs args);
  Future<void> transformAsync<TArgs>(AsyncStateTransform<TState, TArgs> transform, TArgs args);
  Stream<Trace<TState>> get trace;
}
```

Holds state and runs transforms.

| Method | Description |
|---|---|
| `StateContainer(value, {onCreate})` | Constructor. If `onCreate` is provided, it is called once after construction with the new container. |
| `transform(transform, args)` | Apply a sync transform, set new state, dispatch effect. |
| `transformAsync(transform, args)` | Apply an async transform, set state per emission. |
| `addDispatcher(dispatcher)` | Prepend a dispatcher to the effect chain. `null` is ignored. |
| `removeDispatcher(dispatcher)` | Remove a dispatcher from the chain. `null` and unknown dispatchers are ignored. |
| `trace` | Lazy broadcast stream of `Trace` records for debugging. |

### `Trace<TState>`

```dart
typedef Trace<TState> = ({
  int runId,
  TState stateIn,
  TState stateOut,
  Effect effectOut,
  Object func,
  Object? args,
});
```

Diagnostic record emitted to `StateContainer.trace`.

### `Dispatcher`

```dart
typedef Dispatcher = Effect? Function(Effect effect);
```

Interceptor that receives an effect. Return the (possibly modified) effect to
continue the chain, or `null` to stop it.

---

### `StateProvider<TState>`

```dart
// Create and own a container (auto-disposed):
StateProvider<TState>(
  create: (_) => InitialState(),
  onCreate: (c) => c.addDispatcher(myDispatcher),
  child: MyApp(),
);

// Inject an existing container:
StateProvider<TState>.value(
  value: existingContainer,
  child: MyApp(),
);
```

### `StateWatcher<TState>`

```dart
StateWatcher<TState>(
  builder: (context, state, child) => Text('$state'),
)
```

Rebuilds on every value change.

### `StateSelector<TState, TSelected>`

```dart
StateSelector<AuthState, bool>(
  select: (state) => state.someField,
  builder: (context, selected, child) => Text('$selected'),
)
```

Rebuilds only when the selected value changes.

### `EffectDispatcher<TState>`

```dart
EffectDispatcher<AuthState>(
  dispatcher: (effect) {
    if (effect is Navigate) {
      navigatorKey.currentState?.pushNamed(effect.route);
      return null; // consumed — stop chain
    }
    return effect;
  },
  child: MyApp(),
)
```

Attaches a [Dispatcher] to the nearest `StateContainer<TState>` in the tree.
The dispatcher is added on mount and removed when the widget is disposed or
the underlying container is replaced.

Use this to wire per-feature effect handlers directly into the widget tree
— e.g. routing, snackbars, logging — without coupling them to feature
transforms.

---

### `services` (global `GetIt`)

```dart
GetIt get services => GetIt.instance;
```

Global service locator for registering repositories, services, etc.

### `RegisterState` extension

```dart
services.registerState<AuthState>(
  const Unauthenticated(),
  onCreate: (c) => c.addDispatcher(authDispatcher),
);
```

Registers a lazy singleton `StateContainer<TState>` in GetIt.

```dart
final authContainer = services.getState<AuthState>();
```

Retrieves the registered `StateContainer<TState>` by type — a typed convenience
wrapper around `get<StateContainer<TState>>()`. Throws if no container is
registered for `TState`.

---

## Testing

The [`yield_test`](https://pub.dev/packages/yield_test) package provides
helpers tailored to the yield-state shape.

### `testTransform`

```dart
testTransform<AuthState, Creds>(
  'login emits LoggedIn state',
  initialState: const LoggedOut(),
  transform: handleLogin,
  args: ('a@b.com', 'pw'),
  expectedState: isA<LoggedIn>(),
  expectedEffects: [isA<Navigate>()],
);
```

### `testAsyncTransform`

```dart
testAsyncTransform<AuthState, Creds>(
  'login emits Loading then LoggedIn',
  initialState: const LoggedOut(),
  asyncTransform: login,
  args: ('a@b.com', 'pw'),
  expectedStates: [isA<AuthLoading>(), isA<LoggedIn>()],
  expectedEffects: [isA<Navigate>()],
);
```

### `testFlow`

```dart
testFlow<AuthState>(
  'login flow produces ordered states and effects',
  initialState: const LoggedOut(),
  act: (container) async {
    await container.transformAsync(login, ('a@b.com', 'pw'));
  },
  expectStates: [isA<AuthLoading>(), isA<LoggedIn>()],
  expectEffects: [isA<Navigate>()],
);
```

## AI Skill
There are two skills in the repository that you can use with whatever ai coder solution that supports it.
1. **yield-state**: A skill that quickly teaches the AI the full api of the package
2. **correctness-by-construction**: A larger skill file that also tries to force the AI into a solid coding pattern for flutter applications.
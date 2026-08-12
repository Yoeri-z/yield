---
name: yield-state
description: Return-driven state management for Flutter. Use when working with `StateContainer`, `StateTransform`, `Effect`, dispatcher chains, or the `yield_state` package APIs.
metadata:
  model: models/minimax-m3
  last_modified: Wed, 12 Aug 2026 00:00:00 GMT
---

# yield-state

Return-driven state management for Flutter. Every transition is a pure
function `(State, Effect)`. State machines in code, not in code-smell.

## Mental model

Transforms describe: "given current state and args, return next state and
effect to dispatch." Nothing else. No mutation, no I/O, no widget coupling.

Side-effects (snackbars, navigation, analytics) cross to the framework via a
dispatcher chain. The transform doesn't know or care who handles them.

## Primitives

| Type | Shape | Purpose |
|---|---|---|
| `Yield<TState>` | `typedef Yield<TState> = (TState, Effect)` | Return shape of every transform |
| `StateTransform<TState, TArgs>` | `Yield<TState> Function(TState, TArgs)` | Sync transform |
| `AsyncStateTransform<TState, TArgs>` | `Stream<Yield<TState>> Function(TState, TArgs)` | Multi-step async transform |
| `StateContainer<TState>` | `ValueNotifier<TState>` + `transform/transformAsync` | Holds state, runs transforms, dispatches effects |
| `Effect` | abstract base | Side-effect token |
| `NoEffect` | sentinel | Unpack returns `[]` — silently dropped |
| `MultiEffect` | wraps `List<Effect>` | `unpack()` flattens; combine with `+` |
| `Dispatcher` | `Effect? Function(Effect)` | Intercept effect. Return next or `null` to stop |
| `Trace<TState>` | record | `stateIn`, `stateOut`, `effectOut`, `runId` — debug stream |

## State

Sealed hierarchy. Compiler enforces exhaustive switch.

```dart
sealed class AuthState {}
class Unauthenticated extends AuthState { const Unauthenticated(); }
class Authenticating extends AuthState { const Authenticating(); }
class Authenticated extends AuthState {
  final User user; const Authenticated(this.user);
}
```

## Effects

Sealed hierarchy per domain. Pure tokens — no behavior.

```dart
sealed class AuthEffect extends Effect {}
class Navigate extends AuthEffect {
  final String route; const Navigate(this.route);
}
class ShowToast extends AuthEffect {
  final String message; const ShowToast(this.message);
}
```

Combine with `+` — auto-flattens nested `MultiEffect`, drops `NoEffect`:

```dart
Navigate('/home') + ShowToast('Welcome')
```

## Transforms

```dart
(AuthState, Effect) login(AuthState s, Creds c) => switch (s) {
  Unauthenticated() => (const Authenticating(), const NoEffect()),
  Authenticating()   => (const Unauthenticated(), const ShowToast('busy')),
  Authenticated()    => (s, const NoEffect()),
};
```

Async — emit one yield per step:

```dart
Stream<(AuthState, Effect)> loginAsync(AuthState s, Creds c) async* {
  yield (const Authenticating(), const NoEffect());
  try {
    final user = await services<AuthRepo>().login(c.email, c.password);
    if (user == null) {
      yield (const Unauthenticated(), const ShowToast('invalid'));
    } else {
      yield (Authenticated(user), const Navigate('/home'));
    }
  } catch (_) {
    yield (const Unauthenticated(), const ShowToast('failed'));
  }
}
```

## StateContainer

```dart
final container = StateContainer<int>(0, onCreate: (c) => c.addDispatcher(myDispatcher));
container.transform<int>((s, a) => (s + a, const NoEffect()), 5);
container.transformAsync<void>((s, _) async* { yield (1, NoEffect()); yield (2, NoEffect()); }, null);
container.removeDispatcher(myDispatcher); // when done
container.dispose(); // clears dispatchers, closes trace stream
```

| Method | Notes |
|---|---|
| `StateContainer(value, {onCreate})` | Constructor. `onCreate` is called once after construction with the new container. |
| `transform(t, args)` | Sync, one yield, sets state, dispatches effect |
| `transformAsync(t, args)` | Streams yields, sets state per emission, dispatches each |
| `addDispatcher(d)` | Prepend dispatcher to chain. `null` is ignored |
| `removeDispatcher(d)` | Remove dispatcher from chain. `null` and unknown dispatchers are ignored |
| `trace` | Lazy broadcast `Stream<Trace<TState>>` — diagnostics |

Static:
```dart
StateContainer.effectDispatcher = (e) { print(e); return e; }; // global, all new containers
```

## Global locator: `services`

Re-exported `GetIt` instance. Import once: `import 'package:yield_state/yield_state.dart';`

```dart
services.registerState<AuthState>(
  const LoggedOut(),
  onCreate: (c) => c.addDispatcher(authDispatcher),
);
services.getState<AuthState>().transform(login, creds);
```

`registerState<TState>(initialState, {onCreate, instanceName})` —
lazy singleton `StateContainer`. `onCreate` is called once after construction
for custom setup (e.g. adding dispatchers).
`getState<TState>({instanceName})` — typed convenience wrapper around
`get<StateContainer<TState>>()`. Retrieves the registered container for `TState`.
## Widgets

```dart
// Create+own container (auto-disposed). .value injects existing.
StateProvider<AuthState>(
  create: (_) => services<StateContainer<AuthState>>().value,
  onCreate: (c) => c.addDispatcher(authDispatcher),
  child: MaterialApp(home: ...),
)

// Rebuild on every state change.
StateWatcher<AuthState>(builder: (ctx, s, _) => Text('$s'))

// Rebuild only when projected value changes.
StateSelector<AuthState, bool>(
  select: (s) => s is Authenticated,
  builder: (ctx, authed, _) => authed ? HomePage() : LoginPage(),
)

// Dispatch from a widget.
context.read<StateContainer<AuthState>>().transform(login, creds);

// Attach a dispatcher to the nearest container in the tree.
// The dispatcher is added on mount and removed on dispose.
EffectDispatcher<AuthState>(
  dispatcher: (e) {
    if (e is Navigate) {
      navigatorKey.currentState?.pushNamed(e.route);
      return null;
    }
    return e;
  },
  child: MyApp(),
)
```

## File layout

Standard clean architecture. Three layers at the project root, with
features grouped inside each. Cross-cutting concerns (shared services, app
shell) live at the root.

```
lib/
  app.dart                         # root StateProvider tree, MaterialApp.router
  main.dart                        # registerServices() + runApp
  shared/                          # cross-cutting
    services/                      # root-owned singleton services
      api_client.dart
      analytics.dart
    themes/
    widgets/                       # generic, reusable widgets
  domain/                          # pure Dart — no Flutter, no IO
    auth/
      auth_state.dart              # sealed state classes
      auth_effect.dart             # sealed effect classes
      auth_transforms.dart         # pure transforms
      pure/                        # pure IO functions (validation, parsing)
        email.dart
    cart/
      ...
    catalog/
      ...
  data/                            # IO, repositories, APIs
    auth/
      auth_repo_impl.dart          # implements AuthRepo
      auth_repo_mock.dart          # in-memory mock for tests
    cart/
      ...
    catalog/
      ...
  ui/                              # widgets, pages
    auth/
      auth_page.dart
      login_form.dart
      auth_provider.dart           # StateProvider wiring, dispatchers
    cart/
      ...
    catalog/
      ...
  tests/                           # mirrors the structure it tests
    domain/auth/auth_transforms_test.dart
    domain/auth/pure/email_test.dart
    ui/auth/
    data/auth/
```

## Rules

- Three layers at the root: `domain/`, `data/`, `ui/`. Features grouped inside each.
- `domain/` is pure Dart — no Flutter, no IO. Imports only from `domain/` or `shared/`.
- `data/` imports `domain/`. Never the reverse.
- `ui/` imports `domain/`. May import `data/` only for wiring.
- `tests/` mirrors the structure it tests.
- Transforms return `(State, Effect)`. Never `void`.
- **Prefer pure IO over state machines.** State machines only when state must
  persist across calls. Pure functions are simpler to test.
- State classes: `sealed`. Effects: `sealed`. Switch exhaustive.
- `NoEffect()` for transitions that emit nothing. Never `null`.
- Transforms pure — no widget imports, no direct I/O. Use `services<T>()`.
- Effects dispatched via the chain. Dispatchers handle framework calls.
- `StateContainer` owned by `StateProvider` (auto-dispose) or registered via
  `services.registerState` (singleton). Never owned ad-hoc in widgets.

## Testing

**Every transform gets a test before it lands.** TDD is mandatory.

Use [`yield_test`](https://pub.dev/packages/yield_test):

```dart
testTransform<AuthState, Creds>(...)        // sync
testAsyncTransform<AuthState, Creds>(...)  // async stream
testFlow<AuthState>(...)                   // container-level integration
```

Details: `yield_state` README → Testing section.

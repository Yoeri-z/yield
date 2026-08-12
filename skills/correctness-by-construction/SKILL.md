---
name: correctness-by-construction
description: Architecture rules and methodology for building Flutter apps on top of `yield_state`. Enforces pure functions over state machines, the statemachine pattern when state persists, sealed classes, abstract interface contracts, and TDD. Use when designing clean architecture, layering, service registration, or writing transforms.
metadata:
  model: models/minimax-m3
  last_modified: Wed, 12 Aug 2026 00:00:00 GMT
---

# Correctness-by-Construction

This document defines the **correctness-by-construction** methodology: the
architecture, rules, and patterns used to build Flutter apps on top of the
**`yield_state`** package. The two go hand in hand — `yield_state` provides
the primitives (`StateContainer`, transforms, `Effect`, `Dispatcher`), and
correctness-by-construction prescribes how to use them.

- Need the API for `(State, Effect)` transform functions, `StateContainer`,
  dispatchers, widgets? → read [`yield-state`](../yield-state/SKILL.md).
- Need the rules for structuring code, layering, services, testing? → keep
  reading this document.

When in doubt: read this document first. The rules below shape everything
you do with `yield_state`.

## ⚠️ TWO IRON RULES — ALWAYS ENFORCED

### Rule 1: Every function MUST return a value

No `void`. A function that produces nothing is a function that should not
exist. The compiler must be able to prove what every call site receives.

**Prefer pure input/output over state machines.** A function that takes
inputs and returns a result is better than one that mutates state. Only
reach for a state machine when the result depends on evolving state.

```dart
// WRONG — void, mutation, no return
void fullName(String first, String last) { /* implicit return */ }
void increment(Counter c) { c.value++; }
void save(User u) { db.write(u); }

// RIGHT — pure input/output (PREFERRED)
String fullName(String first, String last) => '$first $last';
bool isValidEmail(String e) => RegExp(r'^[^@]+@[^@]+$').hasMatch(e);
(num, num) parsePrice(String s) => (whole, cents);

// RIGHT — state machine (only when state actually persists across calls)
(AuthState, Effect) login(AuthState s, Creds c) => switch (s) {
  LoggedOut() => (const Authenticating(), const NoEffect()),
  _ => (s, const NoEffect()),
};
```

### Rule 2: State always follows the STATEMACHINE PATTERN

When state must persist across calls (UI state, multi-step flows, tokens,
session, etc.), never mutate it in place. State changes are pure
transitions `(stateIn, args) → (stateOut, effect)`. Hold state in a
`StateContainer`. Inject via `StateProvider`. Register via
`services.registerState`. Model the state space as sealed classes.

```dart
sealed class AuthState {}
class LoggedOut extends AuthState { const LoggedOut(); }
class LoggedIn extends AuthState { final User user; const LoggedIn(this.user); }

(AuthState, Effect) login(AuthState s, Creds c) => switch (s) {
  LoggedOut() => switch (services<AuthRepo>().login(c)) {
    User u => (LoggedIn(u), const Navigate('/home')),
    null  => (s, const ShowToast('failed')),
  },
  LoggedIn() => (s, const NoEffect()),
};

services.registerState<AuthState>(const LoggedOut(), onCreate: (c) => c.addDispatcher(authDispatcher));
services.getState<AuthState>().transform(login, creds);
```

### Rule 3: Every transform gets a test the moment it is created

A transform without a test is a bug in waiting. TDD is mandatory: write the
test first, watch it fail, write the transform, watch it pass. A transform
that lands in a PR without a test is rejected.

```dart
// 1. Write the test FIRST
testTransform<AuthState, Creds>(
  'login with valid creds emits LoggedIn',
  initialState: const LoggedOut(),
  transform: handleLogin,
  args: const Creds('a@b.com', 'pw'),
  expectedState: isA<LoggedIn>(),
  expectedEffects: [isA<Navigate>()],
);

// 2. Then write the transform
(AuthState, Effect) handleLogin(AuthState s, Creds c) => ...;
```

Async transforms → `testAsyncTransform`. Multi-call flows → `testFlow`.
Pure IO functions → `test`. Same rule, no exceptions.

---

## Decision rule: pure IO vs. state machine

```
Does the result depend on state that persists across calls?
│
├── No  →  Pure function. Input → Output. No state machine.
│         Examples: validation, parsing, formatting, computation, mapping.
│         Tests: plain `test(...)`.
│
└── Yes →  State machine. `(stateIn, args) → (stateOut, effect)`.
          Examples: auth flow, wizard, poll, multi-step fetch.
          Tests: `testTransform`, `testAsyncTransform`, `testFlow`.
```

Pure IO is the default. State machines are the exception. Every state
machine should be justified by an explicit reason. Pure IO is free.

---

## Architecture: Clean Architecture

Three layers at the project root. Each layer is grouped by feature inside
it. Dependencies flow inward only.

```
┌─────────────────────────────────────────┐
│  ui/      (Widgets, Pages)              │  reads state, dispatches transforms
├─────────────────────────────────────────┤
│  data/    (Repo Impls, API clients, DB) │  implements contracts, IO, persistence
├─────────────────────────────────────────┤
│  domain/  (State, Effects, Transforms,  │  pure logic, sealed classes,
│            Service Contracts, Pure IO)  │  interfaces only
└─────────────────────────────────────────┘
```

`domain/` imports nothing from `data/` or `ui/`. `data/` imports `domain/`
(to implement contracts). `ui/` imports both `domain/` (to read state and
dispatch) and `data/` only for wiring (provider setup).

### Directory layout

```
lib/
  app.dart                         # root StateProvider tree, MaterialApp.router
  main.dart                        # registerServices() + runApp
  shared/                          # cross-cutting — used by multiple features
    services/                      # root-owned singleton services
      api_client.dart
      analytics.dart
    themes/
    widgets/                       # generic, reusable widgets
  domain/                          # pure Dart — no Flutter, no IO
    auth/
      auth_state.dart              # sealed state classes
      auth_effect.dart             # sealed effect classes
      auth_repo.dart               # abstract interface contract
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
    domain/
      auth/
        auth_transforms_test.dart
        pure/email_test.dart
    data/
      auth/
    ui/
      auth/
```

### Layer rules

| Layer | May import | May NOT import |
|---|---|---|
| `domain/` | `shared/`, other features' `domain/` | `data/`, `ui/`, Flutter, IO |
| `data/` | its own `domain/`, `shared/` | other features' `data/`, `ui/` |
| `ui/` | `domain/`, `data/` (only for wiring), `shared/` | other features' internals |
| `tests/` | everything in its feature | — |

Each feature is replaceable. Swapping `data/auth/` for a new impl does not
touch `domain/auth/`. A new feature is added by creating a new slice under
each layer — never by editing another feature's slice.

---

## Service Contracts: Strict Interfaces

Every external dependency is an `abstract interface class` in the domain
layer. Implementations live in the data layer. Transforms and pure IO
never import implementations — only contracts.

```dart
// lib/domain/auth/auth_repo.dart — contract
abstract interface class AuthRepo {
  User? login(String email, String password);
  Future<bool> logout();
  Stream<User?> get onAuthChanged;
}

// lib/data/auth/auth_repo_impl.dart — impl
class AuthRepoImpl implements AuthRepo {
  final ApiClient _api;
  AuthRepoImpl(this._api);
  @override
  User? login(String email, String password) => _api.post('/login', {'email': email, 'password': password});
  @override
  Future<bool> logout() async { await _api.post('/logout', {}); return true; }
  @override
  Stream<User?> get onAuthChanged => _api.stream('/auth');
}
```

Rules:

- `abstract interface class` (Dart 3). No `extends` on other contracts.
- Narrow: only the methods transforms need. Interface Segregation.
- One contract per concern. No god-interfaces.
- `Stream` for reactive, `Future` for one-shot. Constructor-inject deps.
- Domain imports = contracts only. Implementations never leak in.

---

## Registration and Injection

Each feature exposes a `register(services)` function. The root composes
them in `main()`. This keeps feature wiring inside the feature and the
root thin.

```dart
// lib/domain/auth/auth_registration.dart
void registerAuth(GetIt s) {
  s.registerLazySingleton<AuthRepo>(() => AuthRepoImpl(s()));
  s.registerState<AuthState>(const LoggedOut(), onCreate: (c) => c.addDispatcher(authDispatcher));
}

// lib/domain/cart/cart_registration.dart
void registerCart(GetIt s) {
  s.registerLazySingleton<CartRepo>(() => CartRepoImpl(s()));
  s.registerState<CartState>(const CartEmpty());
}

// lib/main.dart
void main() {
  registerServices();
  runApp(const MyApp());
}

void registerServices() {
  // Shared infra
  services.registerLazySingleton<ApiClient>(() => ApiClient('https://api'));
  services.registerLazySingleton<Analytics>(() => Analytics());

  // Each feature owns its own registrations
  registerAuth(services);
  registerCart(services);
  registerCatalog(services);

  // Global effect dispatcher (optional — fires for all new containers)
  StateContainer.effectDispatcher = (e) { analytics.log(e); return e; };
}
```

Retrieve in transforms (always sync `services<T>()`):

```dart
(AuthState, Effect) doThing(AuthState s, Creds c) {
  final repo = services<AuthRepo>();
  // ...
}
```

---

## StateContainer, StateProvider, registerState

| Tool | Role |
|---|---|
| `StateContainer<TState>(value, {onCreate})` | Holds state. `onCreate` called once after construction. `transform` / `transformAsync`. Effect dispatch chain. |
| `StateProvider<TState>` | Widget-tree injection. Create-and-own (auto-dispose) or `.value`. Supports `onCreate`. |
| `services.registerState<TState>(initial, {onCreate})` | Lazy singleton `StateContainer` in GetIt. |
| `services.getState<TState>({instanceName})` | Retrieve registered `StateContainer<TState>` by type. |

```dart
final container = StateContainer<int>(0, onCreate: (c) => c.addDispatcher(logger));
container.transform<int>((s, a) => (s + a, const NoEffect()), 5);

StateProvider<AuthState>(
  create: (_) => const LoggedOut(),
  onCreate: (c) => c.addDispatcher(authDispatcher),
  child: MaterialApp(home: ...),
);

services.registerState<AuthState>(const LoggedOut(), onCreate: (c) => c.addDispatcher(authDispatcher));

// Retrieve the registered container:
final auth = services.getState<AuthState>();
auth.transform(login, creds);
```

---

## Dispatchers

A `Dispatcher` receives an effect, may transform/replace it, and returns
the effect to continue or `null` to stop. Chain is FIFO; `addDispatcher`
prepends, `removeDispatcher` removes. `NoEffect` is dropped before
dispatchers fire.

```dart
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

Dispatcher routerDispatcher = (e) {
  if (e is Navigate) {
    navigatorKey.currentState?.pushNamed(e.route);
    return null; // consumed — stop chain
  }
  return e;
};

Dispatcher toastDispatcher = (e) {
  if (e is ShowToast) {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
  return e;
};
```

Wire order — first added = first fired:

```dart
container.addDispatcher(toastDispatcher); // swallowed first
container.addDispatcher(routerDispatcher);
```

Or globally: `StateContainer.effectDispatcher = ...` (fires for all new containers).

### `EffectDispatcher<TState>` widget

For per-feature handlers in the widget tree, use `EffectDispatcher`. It
attaches a dispatcher to the nearest `StateContainer<TState>` in the tree,
removes it on dispose, and swaps it automatically when the container
identity changes.

```dart
// In a feature's UI module:
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

Prefer `EffectDispatcher` for widget-tree-bound handlers (routing,
toasts, analytics) and the `dispatcher` parameter on `StateProvider` /
`services.registerState` for app-wide handlers.

---

## Testing

### Rule: every transform/fn gets a test before it lands

- Pure IO function → `test` in same file or `*_test.dart`.
- Sync transform → `testTransform` in `transforms_test.dart`.
- Async transform → `testAsyncTransform`.
- Multi-call flow → `testFlow`.

A PR without matching tests is rejected. No exceptions.

### Pure IO tests

```dart
test('isValidEmail rejects missing @', () {
  expect(isValidEmail('foo'), isFalse);
  expect(isValidEmail('a@b.com'), isTrue);
});
```

### Transform tests

```dart
testTransform<AuthState, Creds>(
  'login with valid creds → LoggedIn',
  initialState: const LoggedOut(),
  transform: handleLogin,
  args: const Creds('a@b.com', 'pw'),
  expectedState: isA<LoggedIn>(),
  expectedEffects: [isA<Navigate>()],
);

testAsyncTransform<AuthState, Creds>(
  'login stream: Loading → LoggedIn',
  initialState: const LoggedOut(),
  asyncTransform: loginAsync,
  args: const Creds('a@b.com', 'pw'),
  expectedStates: [isA<AuthLoading>(), isA<LoggedIn>()],
  expectedEffects: [isA<Navigate>()],
);

testFlow<AuthState>(
  'full login flow',
  initialState: const LoggedOut(),
  act: (c) async => c.transformAsync(loginAsync, creds),
  expectStates: [isA<AuthLoading>(), isA<LoggedIn>()],
  expectEffects: [isA<Navigate>()],
);
```

### Mocking services in tests

```dart
setUp(() {
  services.registerSingleton<AuthRepo>(MockAuthRepo());
  services.registerState<AuthState>(const LoggedOut());
});

tearDown(() => services.reset());

test('login calls repo.login', () {
  when(services<AuthRepo>().login(any, any)).thenReturn(testUser);
  services.getState<AuthState>().transform(handleLogin, creds);
  verify(services<AuthRepo>().login(creds.email, creds.password)).called(1);
});
```

---

## Diet Rules

| Rule | Why |
|---|---|
| No `void` | Compiler enforces every function's return shape |
| Pre pure IO over state machine | Pure functions are simpler, more testable, no state to manage |
| Pure transforms when state persists | `(State, Effect)` or `Stream<(State, Effect)>` |
| State = sealed class | Compiler enforces exhaustive switch + dispatch |
| Effects = sealed class | Compiler enforces exhaustive dispatcher mapping |
| TDD: test before transform | A transform without a test is a bug in waiting |
| `abstract interface class` for services | Domain never imports implementations |
| `services<T>()` for deps | No instantiation in transforms |
| `services.registerState` for containers | Single registration point, no naked containers |
| `services.reset()` in test tearDown | Isolate tests from shared locator state |
| Dispatchers handle side-effects | Transforms never call widgets, navigation, DB |

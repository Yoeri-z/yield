/// Yield-state: return-driven state management for Flutter.
///
/// State is updated via pure functions that return a `(TState, Effect)` record.
/// Effects are dispatched through a chain of [Dispatcher]s, decoupling
/// business logic from side-effect handling.
///
/// The three core primitives:
/// - [Yield] — a `(TState, Effect)` record.
/// - [StateContainer] — holds state and runs transforms.
/// - [Effect] — represents a side-effect to be dispatched.
///
/// Widgets interact with state through [StateProvider], [StateWatcher],
/// and [StateSelector].
library;

import 'package:get_it/get_it.dart';

export './src/state/container.dart';
export './src/state/effect.dart';
export './src/state/yield.dart';

export './src/widgets/providers.dart';
export './src/widgets/consumers.dart';

export './src/get_it_extension.dart';

/// Global service locator.
///
/// Use this to register and retrieve repositories, services, and other
/// long-lived dependencies that transforms need at runtime.
GetIt get services => GetIt.instance;

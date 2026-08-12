import 'package:provider/provider.dart';
import 'package:yield_state/yield_state.dart';

/// Provides a [StateContainer] to the widget tree using [Provider].
///
/// Use the default constructor to create and own a container (auto-disposed
/// when the widget is removed from the tree). Use [StateProvider.value] to
/// inject an existing container.
///
/// ```dart
/// StateProvider<int>(
///   create: (_) => 0,
///   child: MyApp(),
/// );
/// ```
class StateProvider<TState> extends ListenableProvider<StateContainer<TState>> {
  /// Creates and registers a new [StateContainer] with the given [create] callback.
  ///
  /// Use the optional [onCreate] callback for custom post-construction setup
  /// (e.g. adding dispatchers, running an initial transform).
  StateProvider({
    super.key,
    required Create<TState> create,
    void Function(StateContainer<TState> container)? onCreate,
    super.child,
    super.builder,
    super.lazy,
  }) : super(
         create: (context) => StateContainer(create(context), onCreate: onCreate),
       );

  /// Injects an existing [StateContainer] into the tree.
  ///
  /// The container is not disposed by the provider — the caller owns its lifecycle.
  StateProvider.value({
    super.key,
    required super.value,
    super.child,
    super.builder,
  }) : super.value(
         updateShouldNotify: (previous, current) =>
             previous.value != current.value,
       );
}

import 'package:yield_state/yield_state.dart';

import 'package:get_it/get_it.dart';

/// Extension on [GetIt] for registering [StateContainer] instances.
extension RegisterState on GetIt {
  /// Registers a lazy singleton [StateContainer] with [initialState].
  ///
  /// The container is created on first retrieval and disposed automatically
  /// when GetIt is reset. Optionally provide a [dispatcher] to handle effects
  /// produced by this container's transforms.
  void registerState<TState>(
    TState initialState, {
    String? instanceName,
    Dispatcher? dispatcher,
    void Function(StateContainer<TState> container)? onCreated,
  }) => registerLazySingleton(
    () => StateContainer(initialState)..addDispatcher(dispatcher),
  );
}

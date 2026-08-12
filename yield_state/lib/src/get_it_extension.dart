import 'package:yield_state/yield_state.dart';

import 'package:get_it/get_it.dart';

/// Extension on [GetIt] for registering [StateContainer] instances.
extension RegisterState on GetIt {
  /// Registers a lazy singleton [StateContainer] with [initialState].
  ///
  /// The container is created on first retrieval and disposed automatically
  /// when GetIt is reset. Use the optional [onCreate] callback for custom
  /// post-construction setup such as adding dispatchers.
  void registerState<TState>(
    TState initialState, {
    String? instanceName,
    void Function(StateContainer<TState> container)? onCreate,
  }) => registerLazySingleton(
    () => StateContainer(initialState, onCreate: onCreate),
    instanceName: instanceName,
  );

  /// Retrieves the registered [StateContainer] for [TState] from GetIt.
  ///
  /// This is a typed convenience wrapper around `get<StateContainer<TState>>()`.
  /// Use it in transforms or UI code to access a previously registered container
  /// without the verbose generic syntax:
  ///
  /// ```dart
  /// // Instead of:
  /// services.get<StateContainer<AuthState>>()
  /// // Write:
  /// services.getState<AuthState>()
  /// ```
  StateContainer<TState> getState<TState>({String? instanceName}) =>
      get<StateContainer<TState>>(instanceName: instanceName);
}

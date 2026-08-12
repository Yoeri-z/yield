import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:yield_state/yield_state.dart';

/// Watches the entire [StateContainer] and rebuilds on every value change.
///
/// ```dart
/// StateWatcher<int>(
///   builder: (context, count, _) => Text('$count'),
/// )
/// ```
class StateWatcher<TState> extends SingleChildStatelessWidget {
  /// Creates a watcher that rebuilds with the full [TState].
  const StateWatcher({super.key, required this.builder, super.child});

  /// Builder called with the current [TState] value.
  final Widget Function(BuildContext context, TState value, Widget? child)
  builder;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    final providerContainer = context.watch<StateContainer<TState>?>();

    if (providerContainer != null) {
      return builder(context, providerContainer.value, child);
    }

    return ValueListenableBuilder(
      valueListenable: services.getState<TState>(),
      builder: builder,
      child: child,
    );
  }
}

/// Selects a sub-part of [TState] and only rebuilds when the selected value changes.
///
/// ```dart
/// StateSelector<AuthState, bool>(
///   select: (state) => state is Authenticated,
///   builder: (context, isAuth, _) => isAuth ? ... : ...,
/// )
/// ```
class StateSelector<TState, TSelected> extends SingleChildStatelessWidget {
  /// Creates a selector that derives [TSelected] from [TState].
  const StateSelector({
    super.key,
    required this.select,
    required this.builder,
    super.child,
  });

  /// Projection from [TState] to the value to compare for rebuild.
  final TSelected Function(TState) select;

  /// Builder called with the selected value.
  final Widget Function(BuildContext context, TSelected value, Widget? child)
  builder;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    final providerContainer = context.read<StateContainer<TState>?>();

    if (providerContainer != null) {
      return builder(
        context,
        context.select<StateContainer<TState>, TSelected>(
          (container) => select(container.value),
        ),
        child,
      );
    }

    return _ValueListenableSelector<TState, TSelected>(
      valueListenable: services.getState<TState>(),
      select: select,
      builder: builder,
      child: child,
    );
  }
}

class _ValueListenableSelector<T, S> extends StatefulWidget {
  const _ValueListenableSelector({
    required this.valueListenable,
    required this.select,
    required this.builder,
    this.child,
  });

  final ValueListenable<T> valueListenable;
  final S Function(T) select;
  final Widget Function(BuildContext context, S value, Widget? child) builder;
  final Widget? child;

  @override
  State<_ValueListenableSelector<T, S>> createState() =>
      _ValueListenableSelectorState<T, S>();
}

class _ValueListenableSelectorState<T, S>
    extends State<_ValueListenableSelector<T, S>> {
  late S _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.select(widget.valueListenable.value);
    widget.valueListenable.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(_ValueListenableSelector<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_onValueChanged);
      _selectedValue = widget.select(widget.valueListenable.value);
      widget.valueListenable.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged() {
    final newSelectedValue = widget.select(widget.valueListenable.value);
    if (_selectedValue != newSelectedValue) {
      setState(() {
        _selectedValue = newSelectedValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selectedValue, widget.child);
  }
}

/// Register a [Dispatcher] that will deal with events related to transformations of [TState].
///
/// Can block effects from bubbling up by returning null.
class EffectDispatcher<TState> extends StatefulWidget {
  const EffectDispatcher({
    super.key,
    required this.dispatcher,
    required this.child,
  });

  final Dispatcher dispatcher;
  final Widget child;

  @override
  State<EffectDispatcher<TState>> createState() =>
      _EffectDispatcherState<TState>();
}

class _EffectDispatcherState<TState> extends State<EffectDispatcher<TState>> {
  StateContainer<TState>? container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newContainer =
        Provider.of<StateContainer<TState>?>(context) ??
        services.getState<TState>();

    if (!identical(container, newContainer)) {
      container?.removeDispatcher(widget.dispatcher);
      newContainer.addDispatcher(widget.dispatcher);
      container = newContainer;
    }
  }

  @override
  void dispose() {
    container?.removeDispatcher(widget.dispatcher);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

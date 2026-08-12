import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final current = switch (state) {
    CounterLoaded(:final value) => value,
    _ => 0,
  };
  return (CounterLoaded(current + 1), const NoEffect());
}

(CounterState, Effect) decrement(CounterState state, _) {
  final current = switch (state) {
    CounterLoaded(:final value) => value,
    _ => 0,
  };
  final next = current - 1;
  return (CounterLoaded(next), ShowSnackbar(next < 0 ? 'Negative!' : 'OK'));
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
                        onPressed: () => context
                            .read<StateContainer<CounterState>>()
                            .transform(decrement, null),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        onPressed: () => context
                            .read<StateContainer<CounterState>>()
                            .transform(increment, null),
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

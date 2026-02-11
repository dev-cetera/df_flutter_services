## Summary

`df_flutter_services` provides Flutter-specific service classes that respond to app lifecycle events (pause when backgrounded, resume when foregrounded). The base service classes (`Service`, `StreamService`) are in [df_di](https://pub.dev/packages/df_di) - this package adds `ObservedService` variants that integrate with Flutter's `WidgetsBindingObserver`.

This package is designed to work with [df_di](https://pub.dev/packages/df_di) for dependency injection and [df_pod](https://pub.dev/packages/df_pod) for reactive state.

## Core Concepts

| Class | Package | Purpose |
|-------|---------|---------|
| `Service` | df_di | Base service with init/pause/resume/dispose lifecycle |
| `StreamService<TData>` | df_di | Service that manages a data stream |
| `ObservedService` | df_flutter_services | Service that responds to Flutter app lifecycle events |
| `ObservedStreamService<TData>` | df_flutter_services | StreamService + Flutter lifecycle integration |
| `ObservedDataStreamService<TData>` | df_flutter_services | ObservedStreamService with automatic Pod (`pData`) updates |

## Service Lifecycle States

```
NOT_INITIALIZED → init() → RUN_SUCCESS
                            ↓
                          pause() → PAUSE_SUCCESS
                            ↓
                          resume() → RESUME_SUCCESS
                            ↓
                          dispose() → DISPOSE_SUCCESS
```

## Quick Start

### 1. Create a Basic Service

For services that don't need Flutter lifecycle integration, use `Service` from df_di:

```dart
import 'package:df_di/df_di.dart';

final class CounterService extends Service {
  int _count = 0;
  int get count => _count;

  void increment() => _count++;

  @override
  TServiceResolvables<Unit> provideInitListeners(void _) => [
    (_) {
      _count = 0;
      return syncUnit();
    },
  ];

  @override
  TServiceResolvables<Unit> providePauseListeners(void _) => [];

  @override
  TServiceResolvables<Unit> provideResumeListeners(void _) => [];

  @override
  TServiceResolvables<Unit> provideDisposeListeners(void _) => [
    (_) {
      print('CounterService disposed with count: $_count');
      return syncUnit();
    },
  ];
}
```

### 2. Create an ObservedDataStreamService with Reactive State

`ObservedDataStreamService` automatically updates a `pData` Pod when the stream emits, and responds to Flutter app lifecycle:

```dart
import 'package:df_flutter_services/df_flutter_services.dart';

final class StockPriceService extends ObservedDataStreamService<double> {
  final String symbol;
  StockPriceService({required this.symbol});

  // Access reactive state via pData: Pod<Option<Result<double>>>

  @override
  bool handlePausedState() => true;  // Pause stream when app backgrounds

  @override
  bool handleResumedState() => true; // Resume stream when app foregrounds

  @override
  Stream<Result<double>> provideInputStream() {
    return Stream.periodic(
      const Duration(seconds: 1),
      (count) => Ok(100.0 + (count % 10) * 0.5),
    );
  }

  @override
  TServiceResolvables<Result<double>> provideOnPushToStreamListeners() => [
    ...super.provideOnPushToStreamListeners(),
    (data) {
      if (data.isOk()) {
        print('$symbol price: \$${data.unwrap().toStringAsFixed(2)}');
      }
      return syncUnit();
    },
  ];
}

// Usage with PodBuilder:
PodBuilder(
  pod: stockService.pData,
  builder: (context, _) {
    final value = stockService.pData.getValue();
    return value.fold(
      ifNone: () => CircularProgressIndicator(),
      ifSome: (result) => result.fold(
        ifOk: (price) => Text('\$${price.toStringAsFixed(2)}'),
        ifErr: (error) => Text('Error: ${error.error}'),
      ),
    );
  },
)
```

### 3. Register Services with DI

Services integrate seamlessly with `df_di`:

```dart
// Register with lifecycle callbacks
DI.global.register<StockPriceService>(
  StockPriceService(symbol: 'AAPL'),
  onRegister: (service) => service.init(),
  onUnregister: ServiceMixin.unregister, // Calls dispose() automatically
);

// Access anywhere
final stockService = DI.global<StockPriceService>();

// Or wait for async registration
final stockService = await DI.global.untilSuper<StockPriceService>().unwrap();
```

## Best Practices

1. **Always use `ServiceMixin.unregister` for `onUnregister`** - ensures `dispose()` is called
2. **Use `ObservedDataStreamService` for reactive data** - automatic Pod updates and lifecycle handling
3. **Override `provideDisposeListeners`** - clean up resources properly
4. **Use `ObservedService` variants for background-sensitive services** - automatic pause/resume

## Related Packages

- [df_di](https://pub.dev/packages/df_di) - Dependency injection and base Service classes
- [df_pod](https://pub.dev/packages/df_pod) - Reactive state containers
- [df_safer_dart](https://pub.dev/packages/df_safer_dart) - Option, Result, Resolvable types

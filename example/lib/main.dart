// This example demonstrates df_flutter_services.
// Note: This is a Flutter package and requires a Flutter environment to run.
// The ObservedService classes integrate with Flutter's WidgetsBindingObserver.

// ignore_for_file: avoid_print

import 'package:df_di/df_di.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Example 1: A basic Service from df_di (works without Flutter).
///
/// For Flutter apps, use ObservedService from df_flutter_services which
/// automatically responds to app lifecycle events (pause/resume).
final class CounterService extends Service {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
    print('Count incremented to: $_count');
  }

  @override
  TServiceResolvables<Unit> provideInitListeners(void _) {
    return [
      (_) {
        _count = 0;
        print('CounterService initialized');
        return syncUnit();
      },
    ];
  }

  @override
  TServiceResolvables<Unit> providePauseListeners(void _) {
    return [
      (_) {
        print('CounterService paused');
        return syncUnit();
      },
    ];
  }

  @override
  TServiceResolvables<Unit> provideResumeListeners(void _) {
    return [
      (_) {
        print('CounterService resumed');
        return syncUnit();
      },
    ];
  }

  @override
  TServiceResolvables<Unit> provideDisposeListeners(void _) {
    return [
      (_) {
        print('CounterService disposed with final count: $_count');
        return syncUnit();
      },
    ];
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Example 2: A StreamService that produces stock prices.
///
/// In a Flutter app, you would use ObservedDataStreamService instead which:
/// - Responds to app lifecycle (pause when backgrounded, resume when foregrounded)
/// - Provides a pData Pod for reactive UI updates
final class StockPriceService extends StreamService<double> {
  final String symbol;

  StockPriceService({required this.symbol});

  @override
  Stream<Result<double>> provideInputStream() {
    // Simulate a stock price stream
    return Stream.periodic(const Duration(seconds: 1), (count) {
      final price = 100.0 + (count % 10) * 0.5;
      return Ok(price);
    });
  }

  @override
  TServiceResolvables<Unit> provideInitListeners(void _) {
    return [
      ...super.provideInitListeners(null),
      (_) {
        print('StockPriceService started for $symbol');
        return syncUnit();
      },
    ];
  }

  @override
  TServiceResolvables<Unit> provideDisposeListeners(void _) {
    return [
      (_) {
        print('StockPriceService stopped for $symbol');
        return syncUnit();
      },
      ...super.provideDisposeListeners(null),
    ];
  }

  @override
  TServiceResolvables<Result<double>> provideOnPushToStreamListeners() {
    return [
      (data) {
        if (data.isOk()) {
          UNSAFE:
          print('$symbol price: \$${data.unwrap().toStringAsFixed(2)}');
        }
        return syncUnit();
      },
    ];
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

Future<void> main() async {
  print('=== Service Lifecycle Demo ===\n');

  // --- CounterService Demo ---
  print('--- CounterService ---');
  final counterService = CounterService();

  // Initialize the service
  await counterService.init().value;
  print('State after init: ${counterService.state}');

  // Use the service
  counterService.increment();
  counterService.increment();
  counterService.increment();

  // Demonstrate pause/resume
  await counterService.pause().value;
  print('State after pause: ${counterService.state}');
  await counterService.resume().value;
  print('State after resume: ${counterService.state}');

  // Dispose
  await counterService.dispose().value;
  print('State after dispose: ${counterService.state}\n');

  // --- StockPriceService Demo ---
  print('--- StockPriceService ---');
  final stockService = StockPriceService(symbol: 'AAPL');

  // Initialize and start streaming
  await stockService.init().value;

  // Listen to a few price updates via the stream
  print('Listening for 3 price updates...');
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
  }

  // Clean up
  await stockService.dispose().value;

  // --- DI Integration Demo ---
  print('\n--- DI Integration ---');

  // Register with DI (registerAndInitService chains init() automatically and
  // disposes the service on unregister).
  DI.global.registerAndInitService<CounterService>(CounterService());

  // Access and use the service
  final resolved = await DI.global.untilSuper<CounterService>().value;
  final diCounter = UNSAFE(() => resolved.unwrap());
  diCounter.increment();
  diCounter.increment();
  print('DI Counter value: ${diCounter.count}');

  // Unregister triggers dispose via ServiceMixin.unregister
  await DI.global.unregister<CounterService>().value;
  print('Service unregistered and disposed');

  print('\n=== Demo Complete ===');
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// For Flutter apps, here's how you would use ObservedDataStreamService:
///
/// ```dart
/// import 'package:df_flutter_services/df_flutter_services.dart';
///
/// final class UserDataService extends ObservedDataStreamService<User> {
///   @override
///   bool handlePausedState() => true;  // Pause when app backgrounds
///
///   @override
///   bool handleResumedState() => true; // Resume when app foregrounds
///
///   @override
///   Stream<Result<User>> provideInputStream() {
///     return myUserDataStream();
///   }
///
///   @override
///   TServiceResolvables<Result<User>> provideOnPushToStreamListeners() => [
///     ...super.provideOnPushToStreamListeners(),
///     (data) {
///       // pData Pod is automatically updated by super
///       // Add custom logic here if needed
///       return syncUnit();
///     },
///   ];
/// }
///
/// // In your widget:
/// PodBuilder(
///   pod: userDataService.pData,
///   builder: (context, _) {
///     final value = userDataService.pData.getValue();
///     return value.fold(
///       ifNone: () => CircularProgressIndicator(),
///       ifSome: (result) => result.fold(
///         ifOk: (user) => Text(user.name),
///         ifErr: (error) => Text('Error: ${error.error}'),
///       ),
///     );
///   },
/// )
/// ```

//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Copyright © dev-cetera.com & contributors.
//
// The use of this source code is governed by an MIT-style license described in
// the LICENSE file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

// Regression tests for the WidgetsBindingObserver registration chain. Prior
// to the fix, StreamServiceMixin.provideInitListeners did not call super, so
// the observer-registration listeners on ObservedService never ran for any
// of the stream-based subclasses (ObservedStreamService /
// ObservedDataStreamService / ObservedPollingStreamService). The fix is each
// subclass now re-inserts registerObserver/unregisterObserver explicitly.

import 'dart:async';

import 'package:df_di/df_di.dart';
import 'package:df_flutter_services/df_flutter_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final class _PlainObserved extends ObservedService {
  @override
  bool handlePausedState() => true;
  @override
  bool handleResumedState() => true;
}

final class _StreamObserved extends ObservedStreamService<int> {
  final StreamController<Result<int>> _input =
      StreamController<Result<int>>.broadcast();

  @override
  bool handlePausedState() => true;
  @override
  bool handleResumedState() => true;

  @override
  Stream<Result<int>> provideInputStream() => _input.stream;

  @override
  TServiceResolvables<Result<int>> provideOnPushToStreamListeners() => const [];

  Future<void> closeInput() => _input.close();
}

final class _DataStreamObserved extends ObservedDataStreamService<int> {
  final StreamController<Result<int>> _input =
      StreamController<Result<int>>.broadcast();

  @override
  bool handlePausedState() => true;
  @override
  bool handleResumedState() => true;

  @override
  Stream<Result<int>> provideInputStream() => _input.stream;

  Future<void> closeInput() => _input.close();
}

final class _PollingObserved extends ObservedPollingStreamService<int> {
  @override
  bool handlePausedState() => true;
  @override
  bool handleResumedState() => true;

  @override
  Resolvable<int> onPoll() => Sync.okValue(0);

  @override
  Duration providePollingInterval() => const Duration(seconds: 1);

  @override
  TServiceResolvables<Result<int>> provideOnPushToStreamListeners() => const [];
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Observer registration chain', () {
    test('ObservedService: registers on init, unregisters on dispose',
        () async {
      final s = _PlainObserved();
      expect(s.isObserverRegistered, isFalse);
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);
      (await s.dispose().value).end();
      expect(s.isObserverRegistered, isFalse);
    });

    test('ObservedStreamService: registers on init, unregisters on dispose',
        () async {
      final s = _StreamObserved();
      expect(s.isObserverRegistered, isFalse);
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);
      (await s.dispose().value).end();
      expect(s.isObserverRegistered, isFalse);
      await s.closeInput();
    });

    test('ObservedDataStreamService: registers on init, unregisters on dispose',
        () async {
      final s = _DataStreamObserved();
      expect(s.isObserverRegistered, isFalse);
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);
      (await s.dispose().value).end();
      expect(s.isObserverRegistered, isFalse);
      await s.closeInput();
    });

    test(
        'ObservedPollingStreamService: registers on init, unregisters on dispose',
        () async {
      final s = _PollingObserved();
      expect(s.isObserverRegistered, isFalse);
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);
      (await s.dispose().value).end();
      expect(s.isObserverRegistered, isFalse);
    });

    test(
        'Lifecycle events forwarded via real WidgetsBinding reach a stream-based subclass',
        () async {
      // Smoke test: route the lifecycle event through WidgetsBinding instead
      // of calling didChangeAppLifecycleState directly, so registration is
      // actually exercised.
      final s = _StreamObserved();
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(s.state, ServiceState.PAUSE_SUCCESS);

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(s.state, ServiceState.RESUME_SUCCESS);

      (await s.dispose().value).end();
      await s.closeInput();
    });
  });

  group('pData dispose race', () {
    test('late listener execution after dispose does NOT re-set pData',
        () async {
      // The per-emission listener `(data) => pData.set(Some(data))` lives on
      // its own sequencer. A push initiated pre-dispose can reach the
      // listener post-dispose. The guard should keep pData at None.
      final s = _DataStreamObserved();
      (await s.init().value).end();
      (await s.dispose().value).end();
      expect(s.state.didDispose(), isTrue);
      expect(s.pData.getValue().isNone(), isTrue);

      // Manually invoke each registered listener as the stream sequencer
      // would on a late landing. The guard inside the listener must keep
      // pData as None.
      for (final listener in s.provideOnPushToStreamListeners()) {
        listener(const Ok(123)).end();
      }
      await Future<void>.delayed(Duration.zero);
      expect(s.pData.getValue().isNone(), isTrue);

      await s.closeInput();
    });
  });
}

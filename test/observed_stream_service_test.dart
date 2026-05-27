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

// Coverage for `ObservedStreamService` — the StreamServiceMixin + Flutter
// observer combination without the pData mirror.

import 'dart:async';

import 'package:df_di/df_di.dart';
import 'package:df_flutter_services/df_flutter_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixture ─────────────────────────────────────────────────────────────────

final class _TestStreamService extends ObservedStreamService<int> {
  _TestStreamService({this.opt = true});

  final bool opt;
  final _input = StreamController<Result<int>>.broadcast();
  final pushed = <Result<int>>[];

  @override
  bool handlePausedState() => opt;
  @override
  bool handleResumedState() => opt;

  @override
  Stream<Result<int>> provideInputStream() => _input.stream;

  @override
  TServiceResolvables<Result<int>> provideOnPushToStreamListeners() => [
        (data) {
          pushed.add(data);
          return syncUnit();
        },
      ];

  void emit(int v) => _input.add(Ok(v));
  void emitErr(Object e) => _input.add(Err(e));
  Future<void> closeInput() => _input.close();
}

Future<void> _drain([int times = 2]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ObservedStreamService: basic emission flow', () {
    test('emitted values reach push listeners in order', () async {
      final s = _TestStreamService();
      (await s.init().value).end();

      s.emit(1);
      s.emit(2);
      s.emit(3);
      await _drain(4);

      expect(s.pushed.length, 3);
      expect(s.pushed[0], isA<Ok<int>>());
      UNSAFE(() {
        expect(s.pushed[0].unwrap(), 1);
        expect(s.pushed[1].unwrap(), 2);
        expect(s.pushed[2].unwrap(), 3);
      });

      (await s.dispose().value).end();
      await s.closeInput();
    });

    test('Err emissions reach push listeners as Err', () async {
      final s = _TestStreamService();
      (await s.init().value).end();

      s.emit(1);
      s.emitErr('boom');
      s.emit(2);
      await _drain(4);

      expect(s.pushed.length, 3);
      expect(s.pushed[0].isOk(), isTrue);
      expect(s.pushed[1].isErr(), isTrue);
      expect(s.pushed[2].isOk(), isTrue);

      (await s.dispose().value).end();
      await s.closeInput();
    });
  });

  group('ObservedStreamService: stream getter', () {
    test('stream is None before init and after dispose', () async {
      final s = _TestStreamService();
      expect(s.stream.isNone(), isTrue);

      (await s.init().value).end();
      expect(s.stream.isSome(), isTrue);

      (await s.dispose().value).end();
      expect(s.stream.isNone(), isTrue);

      await s.closeInput();
    });

    test('stream is a broadcast: multiple subscribers see every emission',
        () async {
      final s = _TestStreamService();
      (await s.init().value).end();

      final a = <Result<int>>[];
      final b = <Result<int>>[];
      late StreamSubscription<Result<int>> subA;
      late StreamSubscription<Result<int>> subB;
      UNSAFE(() {
        subA = s.stream.unwrap().listen(a.add);
        subB = s.stream.unwrap().listen(b.add);
      });

      s.emit(10);
      s.emit(20);
      await _drain(4);

      expect(a.length, 2);
      expect(b.length, 2);
      UNSAFE(() {
        expect(a[0].unwrap(), 10);
        expect(b[1].unwrap(), 20);
      });

      await subA.cancel();
      await subB.cancel();
      (await s.dispose().value).end();
      await s.closeInput();
    });
  });

  group('ObservedStreamService: lifecycle pause/resume drives subscription',
      () {
    test('pause() pauses underlying subscription; resume resumes it', () async {
      final s = _TestStreamService();
      (await s.init().value).end();

      // Pause via the service lifecycle (StreamServiceMixin pauses the
      // input subscription as part of its providePauseListeners).
      (await s.pause().value).end();

      // While paused, emitting to the underlying controller should NOT
      // reach the listeners (subscription is paused).
      s.emit(99);
      await _drain();
      expect(s.pushed, isEmpty);

      // Resume drains buffered events.
      (await s.resume().value).end();
      await _drain(4);
      expect(s.pushed.length, 1);
      UNSAFE(() => expect(s.pushed[0].unwrap(), 99));

      (await s.dispose().value).end();
      await s.closeInput();
    });

    test(
      'AppLifecycleState.paused pauses the subscription via the lifecycle '
      'bridge',
      () async {
        final s = _TestStreamService();
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        await _drain();
        expect(s.state, ServiceState.PAUSE_SUCCESS);

        s.emit(7);
        await _drain();
        expect(s.pushed, isEmpty);

        s.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _drain(4);
        expect(s.state, ServiceState.RESUME_SUCCESS);
        expect(s.pushed.length, 1);

        (await s.dispose().value).end();
        await s.closeInput();
      },
    );
  });

  group('ObservedStreamService: initialData', () {
    test('initialData resolves with the first Ok emission', () async {
      final s = _TestStreamService();
      (await s.init().value).end();

      final initial = s.initialData;
      expect(initial.isSome(), isTrue);

      // initialData resolves with the FIRST data point. Emit and await.
      s.emit(42);
      final resolved = await UNSAFE(() => initial.unwrap().toAsync()).value;
      UNSAFE(() => expect(resolved.unwrap(), 42));

      (await s.dispose().value).end();
      await s.closeInput();
    });

    test(
      'initialData resolves with Err if the stream is stopped (disposed) '
      'before any emission — so awaiters never hang',
      () async {
        final s = _TestStreamService();
        (await s.init().value).end();

        final initial = s.initialData;
        UNSAFE(() => expect(initial.isSome(), isTrue));

        // Dispose before emitting; initialData should resolve Err.
        (await s.dispose().value).end();
        final resolved = await UNSAFE(() => initial.unwrap().toAsync()).value;
        UNSAFE(() => expect(resolved.isErr(), isTrue));

        await s.closeInput();
      },
    );
  });

  group('ObservedStreamService: observer registration', () {
    test('observer registered on init, unregistered on dispose', () async {
      final s = _TestStreamService();
      expect(s.isObserverRegistered, isFalse);
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);
      (await s.dispose().value).end();
      expect(s.isObserverRegistered, isFalse);
      await s.closeInput();
    });

    test(
      'A service with opt=false ignores lifecycle events and stays in '
      'RUN_SUCCESS',
      () async {
        final s = _TestStreamService(opt: false);
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        s.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _drain();
        expect(s.state, ServiceState.RUN_SUCCESS);

        (await s.dispose().value).end();
        await s.closeInput();
      },
    );
  });

  group('ObservedStreamService: dispose hygiene', () {
    test(
      'After dispose, the input stream subscription is cancelled — emitting '
      'on the input controller no longer reaches push listeners',
      () async {
        final s = _TestStreamService();
        (await s.init().value).end();
        s.emit(1);
        await _drain();
        expect(s.pushed.length, 1);

        (await s.dispose().value).end();

        s.emit(2);
        await _drain();
        expect(s.pushed.length, 1); // unchanged

        await s.closeInput();
      },
    );
  });
}

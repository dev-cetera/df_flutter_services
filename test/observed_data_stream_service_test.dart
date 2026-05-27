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

// Integration tests for ObservedDataStreamService. Exercises the glue between
// df_di's ServiceMixin / StreamServiceMixin and df_pod's RootPod via the
// pData mirror — the package's main reason to exist.

import 'dart:async';

import 'package:df_di/df_di.dart';
import 'package:df_flutter_services/df_flutter_services.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixture ─────────────────────────────────────────────────────────────────

/// A concrete [ObservedDataStreamService] driven by a manually-fed controller.
final class _TestObservedDataStreamService
    extends ObservedDataStreamService<int> {
  _TestObservedDataStreamService();

  final StreamController<Result<int>> _input =
      StreamController<Result<int>>.broadcast();

  void emit(int value) => _input.add(Ok(value));
  void emitErr(Object error) => _input.add(Err(error));

  @override
  Stream<Result<int>> provideInputStream() => _input.stream;

  Future<void> closeInput() => _input.close();
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ObservedDataStreamService: pData mirror', () {
    test('pData starts as None before any emission', () async {
      final s = _TestObservedDataStreamService();
      expect(s.pData.getValue().isNone(), isTrue);
      (await s.init().value).end();
      expect(s.pData.getValue().isNone(), isTrue);
      (await s.dispose().value).end();
      await s.closeInput();
    });

    test('emit() updates pData to Some(Ok(value))', () async {
      final s = _TestObservedDataStreamService();
      (await s.init().value).end();
      s.emit(42);
      await Future<void>.delayed(Duration.zero);
      switch (s.pData.getValue()) {
        case Some(value: Ok(value: final n)):
          expect(n, 42);
        case Some(value: Err()):
          fail('Expected Some(Ok(42)), got Some(Err)');
        case None():
          fail('Expected Some(Ok(42)), got None');
      }
      (await s.dispose().value).end();
      await s.closeInput();
    });

    test('emitErr() updates pData to Some(Err)', () async {
      final s = _TestObservedDataStreamService();
      (await s.init().value).end();
      s.emitErr('boom');
      await Future<void>.delayed(Duration.zero);
      switch (s.pData.getValue()) {
        case Some(value: Err()):
          break;
        case Some(value: Ok()):
          fail('Expected Some(Err), got Some(Ok)');
        case None():
          fail('Expected Some(Err), got None');
      }
      (await s.dispose().value).end();
      await s.closeInput();
    });

    test('dispose clears pData back to None (does NOT dispose the pod)',
        () async {
      final s = _TestObservedDataStreamService();
      (await s.init().value).end();
      s.emit(7);
      await Future<void>.delayed(Duration.zero);
      expect(s.pData.getValue().isSome(), isTrue);

      (await s.dispose().value).end();
      expect(s.pData.getValue().isNone(), isTrue);
      // The pod itself must still be usable across re-init cycles.
      expect(s.pData.isDisposed, isFalse);
      await s.closeInput();
    });

    test('subsequent emissions replace the previous Some(...)', () async {
      final s = _TestObservedDataStreamService();
      (await s.init().value).end();
      s.emit(1);
      await Future<void>.delayed(Duration.zero);
      s.emit(2);
      await Future<void>.delayed(Duration.zero);
      s.emit(3);
      await Future<void>.delayed(Duration.zero);
      switch (s.pData.getValue()) {
        case Some(value: Ok(value: final n)):
          expect(n, 3);
        case Some(value: Err()):
          fail('Expected Some(Ok(3)), got Some(Err)');
        case None():
          fail('Expected Some(Ok(3)), got None');
      }
      (await s.dispose().value).end();
      await s.closeInput();
    });

    test('pData notifies listeners on each emission', () async {
      final s = _TestObservedDataStreamService();
      (await s.init().value).end();

      final values = <Option<Result<int>>>[];
      final listener = () {
        values.add(s.pData.getValue());
      };

      s.pData.addStrongRefListener(strongRefListener: listener);

      s.emit(10);
      await Future<void>.delayed(Duration.zero);
      s.emit(20);
      await Future<void>.delayed(Duration.zero);

      expect(values.length, 2);
      switch (values[0]) {
        case Some(value: Ok(value: final n)):
          expect(n, 10);
        case _:
          fail('Expected values[0] to be Some(Ok(10))');
      }
      switch (values[1]) {
        case Some(value: Ok(value: final n)):
          expect(n, 20);
        case _:
          fail('Expected values[1] to be Some(Ok(20))');
      }

      // Keep listener alive for the duration of the test, then dispose.
      listener;

      (await s.dispose().value).end();
      await s.closeInput();
    });
  });

  group('ObservedDataStreamService: registered with DI', () {
    test(
      'registerAndInitService + unregister disposes properly through the DI hook',
      () async {
        final di = DI();
        final s = _TestObservedDataStreamService();
        (await di
                .registerAndInitService<_TestObservedDataStreamService>(s)
                .toAsync()
                .value)
            .end();

        expect(s.state, ServiceState.RUN_SUCCESS);

        s.emit(99);
        await Future<void>.delayed(Duration.zero);
        switch (s.pData.getValue()) {
          case Some(value: Ok(value: final n)):
            expect(n, 99);
          case Some(value: Err()):
            fail('Expected Some(Ok(99)), got Some(Err)');
          case None():
            fail('Expected Some(Ok(99)), got None');
        }

        (await di.unregister<_TestObservedDataStreamService>().toAsync().value)
            .end();
        expect(s.state.didDispose(), isTrue);
        expect(s.pData.getValue().isNone(), isTrue);

        await s.closeInput();
      },
    );
  });
}

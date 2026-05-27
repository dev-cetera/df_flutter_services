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

// Tests for HandleServiceLifecycleStateMixin: verifies that AppLifecycleState
// hooks correctly call pause/resume/dispose on the underlying service when
// the corresponding handler returns true (and do nothing when it returns
// false, the default).

import 'package:df_di/df_di.dart';
import 'package:df_flutter_services/df_flutter_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixture ─────────────────────────────────────────────────────────────────

final class _OptInLifecycleService extends ObservedService {
  _OptInLifecycleService({
    this.handlePaused = false,
    this.handleResumed = false,
    this.handleHidden = false,
    this.handleDetached = false,
  });

  final bool handlePaused;
  final bool handleResumed;
  final bool handleHidden;
  final bool handleDetached;

  @override
  bool handlePausedState() => handlePaused;
  @override
  bool handleResumedState() => handleResumed;
  @override
  bool handleHiddenState() => handleHidden;
  @override
  bool handleDetachedState() => handleDetached;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HandleServiceLifecycleStateMixin: defaults are opt-in', () {
    test('with no overrides, app lifecycle changes do NOT touch the service',
        () async {
      final s = _OptInLifecycleService();
      (await s.init().value).end();
      expect(s.state, ServiceState.RUN_SUCCESS);

      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      s.didChangeAppLifecycleState(AppLifecycleState.hidden);
      s.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);

      // No transitions happened.
      expect(s.state, ServiceState.RUN_SUCCESS);

      (await s.dispose().value).end();
    });
  });

  group('HandleServiceLifecycleStateMixin: opt-in handlers', () {
    test('handlePausedState=true → AppLifecycleState.paused calls pause()',
        () async {
      final s = _OptInLifecycleService(handlePaused: true);
      (await s.init().value).end();

      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      // The lifecycle handler kicks off pause() via consec; wait for it.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(s.state, ServiceState.PAUSE_SUCCESS);

      (await s.dispose().value).end();
    });

    test(
      'handleDetachedState=true → AppLifecycleState.detached calls dispose()',
      () async {
        final s = _OptInLifecycleService(handleDetached: true);
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.detached);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(s.state.didDispose(), isTrue);
      },
    );

    test(
      'handleHiddenState=true and handleResumedState=true → pause then resume',
      () async {
        final s = _OptInLifecycleService(
          handleHidden: true,
          handleResumed: true,
        );
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(s.state, ServiceState.PAUSE_SUCCESS);

        s.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(s.state, ServiceState.RESUME_SUCCESS);

        (await s.dispose().value).end();
      },
    );
  });

  group('ObservedService: registers with WidgetsBinding only after init', () {
    test(
      'init/dispose go through cleanly when the observer is wired up',
      () async {
        final s = _OptInLifecycleService(handlePaused: true);
        (await s.init().value).end();
        expect(s.state, ServiceState.RUN_SUCCESS);

        // After init the observer is registered; Flutter would forward lifecycle
        // events to it. Simulate one and verify it propagates to pause().
        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(s.state, ServiceState.PAUSE_SUCCESS);

        (await s.dispose().value).end();
        expect(s.state.didDispose(), isTrue);
      },
    );
  });
}

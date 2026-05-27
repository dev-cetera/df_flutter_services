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

// Exhaustive lifecycle-state transition coverage. Each AppLifecycleState is
// exercised in isolation and in sequences that mirror real OS behaviour
// (e.g. Android: inactive → hidden → paused on backgrounding).

import 'package:df_di/df_di.dart';
import 'package:df_flutter_services/df_flutter_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixture ─────────────────────────────────────────────────────────────────

final class _BoundService extends ObservedService {
  _BoundService({
    this.paused = false,
    this.resumed = false,
    this.hidden = false,
    this.inactive = false,
    this.detached = false,
  });

  final bool paused;
  final bool resumed;
  final bool hidden;
  final bool inactive;
  final bool detached;

  int pauseListenerCalls = 0;
  int resumeListenerCalls = 0;

  @override
  bool handlePausedState() => paused;
  @override
  bool handleResumedState() => resumed;
  @override
  bool handleHiddenState() => hidden;
  @override
  bool handleInactiveState() => inactive;
  @override
  bool handleDetachedState() => detached;

  @override
  TServiceResolvables<Unit> providePauseListeners(void _) => [
        ...super.providePauseListeners(null),
        (_) {
          pauseListenerCalls++;
          return syncUnit();
        },
      ];

  @override
  TServiceResolvables<Unit> provideResumeListeners(void _) => [
        ...super.provideResumeListeners(null),
        (_) {
          resumeListenerCalls++;
          return syncUnit();
        },
      ];
}

Future<void> _drain() async {
  // The lifecycle bridge runs pause/resume/dispose through consec, which
  // schedules the underlying sequencer work as microtasks. Two drains is
  // enough for every test in this file because no listener is async.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Per-state opt-in: each AppLifecycleState in isolation', () {
    test('paused → pause()', () async {
      final s = _BoundService(paused: true);
      (await s.init().value).end();

      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await _drain();

      expect(s.state, ServiceState.PAUSE_SUCCESS);
      expect(s.pauseListenerCalls, 1);

      (await s.dispose().value).end();
    });

    test('resumed → resume() (after a pause)', () async {
      final s = _BoundService(paused: true, resumed: true);
      (await s.init().value).end();

      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await _drain();
      expect(s.state, ServiceState.PAUSE_SUCCESS);

      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _drain();
      expect(s.state, ServiceState.RESUME_SUCCESS);
      expect(s.resumeListenerCalls, 1);

      (await s.dispose().value).end();
    });

    test('hidden → pause()', () async {
      final s = _BoundService(hidden: true);
      (await s.init().value).end();

      s.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await _drain();

      expect(s.state, ServiceState.PAUSE_SUCCESS);
      expect(s.pauseListenerCalls, 1);

      (await s.dispose().value).end();
    });

    test('inactive → pause()', () async {
      final s = _BoundService(inactive: true);
      (await s.init().value).end();

      s.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await _drain();

      expect(s.state, ServiceState.PAUSE_SUCCESS);
      expect(s.pauseListenerCalls, 1);

      (await s.dispose().value).end();
    });

    test('detached → dispose()', () async {
      final s = _BoundService(detached: true);
      (await s.init().value).end();

      s.didChangeAppLifecycleState(AppLifecycleState.detached);
      await _drain();

      expect(s.state.didDispose(), isTrue);
      expect(s.isObserverRegistered, isFalse);
    });
  });

  group('Opt-out states: events have no effect', () {
    test('paused event with handlePausedState=false is a no-op', () async {
      final s = _BoundService();
      (await s.init().value).end();
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await _drain();
      expect(s.state, ServiceState.RUN_SUCCESS);
      expect(s.pauseListenerCalls, 0);
      (await s.dispose().value).end();
    });

    test('resumed event with handleResumedState=false is a no-op', () async {
      final s = _BoundService(paused: true);
      (await s.init().value).end();
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await _drain();
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _drain();
      // Still PAUSE_SUCCESS because resumed is not opted in.
      expect(s.state, ServiceState.PAUSE_SUCCESS);
      expect(s.resumeListenerCalls, 0);
      (await s.dispose().value).end();
    });

    test('detached event without opt-in does not dispose', () async {
      final s = _BoundService(paused: true);
      (await s.init().value).end();
      s.didChangeAppLifecycleState(AppLifecycleState.detached);
      await _drain();
      expect(s.state.didDispose(), isFalse);
      (await s.dispose().value).end();
    });
  });

  group('Multi-state sequences mirroring OS behaviour', () {
    test(
      'Android backgrounding: inactive → hidden → paused. All three opt-in to '
      'pause. After the chain the service is in PAUSE_SUCCESS exactly once.',
      () async {
        final s = _BoundService(inactive: true, hidden: true, paused: true);
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.inactive);
        s.didChangeAppLifecycleState(AppLifecycleState.hidden);
        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        // Drain all queued work in one go.
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(s.state, ServiceState.PAUSE_SUCCESS);
        // Only the first pause runs the listeners; df_di's `pause()` no-ops
        // once the service is already paused.
        expect(s.pauseListenerCalls, 1);

        (await s.dispose().value).end();
      },
    );

    test(
      'iOS foreground tap: inactive → resumed. inactive pauses, resumed '
      'resumes.',
      () async {
        final s = _BoundService(inactive: true, resumed: true);
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await _drain();
        expect(s.state, ServiceState.PAUSE_SUCCESS);

        s.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _drain();
        expect(s.state, ServiceState.RESUME_SUCCESS);

        (await s.dispose().value).end();
      },
    );

    test(
      'Full pause/resume cycle three times runs all listeners each time',
      () async {
        final s = _BoundService(paused: true, resumed: true);
        (await s.init().value).end();

        for (var i = 0; i < 3; i++) {
          s.didChangeAppLifecycleState(AppLifecycleState.paused);
          await _drain();
          expect(s.state, ServiceState.PAUSE_SUCCESS);
          s.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await _drain();
          expect(s.state, ServiceState.RESUME_SUCCESS);
        }

        // Pause runs once per cycle (3); resume same.
        expect(s.pauseListenerCalls, 3);
        expect(s.resumeListenerCalls, 3);

        (await s.dispose().value).end();
      },
    );
  });

  group('Idempotency of repeated same-state events', () {
    test(
      'paused fired three times in a row only runs pause listeners once',
      () async {
        final s = _BoundService(paused: true);
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(s.state, ServiceState.PAUSE_SUCCESS);
        expect(s.pauseListenerCalls, 1);

        (await s.dispose().value).end();
      },
    );

    test(
      'detached fired twice on a detached-opt-in service: first disposes, '
      'second is a no-op (no crash, state stays disposed)',
      () async {
        final s = _BoundService(detached: true);
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.detached);
        await _drain();
        expect(s.state.didDispose(), isTrue);

        // Second detached after dispose must not crash. The bridge calls
        // `dispose()` again, which is a no-op-Ok on a disposed service.
        s.didChangeAppLifecycleState(AppLifecycleState.detached);
        await _drain();
        expect(s.state.didDispose(), isTrue);
      },
    );
  });

  group('Routing through real WidgetsBinding', () {
    test(
      'WidgetsBinding.handleAppLifecycleStateChanged reaches a registered '
      'observer and drives the same state transitions',
      () async {
        final s = _BoundService(paused: true, resumed: true);
        (await s.init().value).end();
        expect(s.isObserverRegistered, isTrue);

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        await _drain();
        expect(s.state, ServiceState.PAUSE_SUCCESS);

        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _drain();
        expect(s.state, ServiceState.RESUME_SUCCESS);

        (await s.dispose().value).end();
        expect(s.isObserverRegistered, isFalse);
      },
    );

    test(
      'After dispose, WidgetsBinding events no longer reach the service '
      '(observer was removed)',
      () async {
        final s = _BoundService(paused: true);
        (await s.init().value).end();
        (await s.dispose().value).end();
        expect(s.isObserverRegistered, isFalse);

        // This event should not touch the service — observer is unregistered.
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        await _drain();

        // The service should still report a disposed state — not transition
        // into PAUSE_ATTEMPT or similar.
        expect(s.state.didDispose(), isTrue);
        expect(s.pauseListenerCalls, 0);
      },
    );
  });

  group('Disposed-terminal-state semantics', () {
    test(
      'After dispose, a fresh paused event from the OS does NOT crash and '
      'is a no-op-Ok (df_di treats dispose as terminal)',
      () async {
        final s = _BoundService(paused: true);
        (await s.init().value).end();
        (await s.dispose().value).end();

        // Manually invoke didChangeAppLifecycleState — simulating an event
        // that arrived between observer registration and unregister. In
        // practice the observer is removed, but this proves the safety guard
        // on the df_di side.
        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        await _drain();

        expect(s.state.didDispose(), isTrue);
      },
    );
  });
}

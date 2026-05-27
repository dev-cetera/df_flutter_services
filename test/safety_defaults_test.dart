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

// Safety-critical regression tests covering the package's "do not crash on
// routine lifecycle events" guarantees:
//   - ObservedService supplies safe `=> const []` defaults for
//     providePauseListeners / provideResumeListeners so a subclass that opts
//     in to handlePausedState() / handleResumedState() but forgets to
//     override the listener providers never crashes when the OS fires the
//     corresponding AppLifecycleState.
//   - Observer registration is idempotent across init/dispose/init cycles.

import 'package:df_di/df_di.dart';
import 'package:df_flutter_services/df_flutter_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixture: a subclass that intentionally does NOT override the listener
//      providers. Before the safer defaults landed this would have inherited
//      the abstract declaration on ServiceMixin and crashed the first time
//      the app entered AppLifecycleState.paused / .resumed. ────────────────

final class _ForgetfulSubclass extends ObservedService {
  // No providePauseListeners / provideResumeListeners overrides on purpose.
  @override
  bool handlePausedState() => true;
  @override
  bool handleResumedState() => true;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ObservedService: safe defaults for pause/resume listeners', () {
    test('providePauseListeners defaults to const []', () {
      final s = _ForgetfulSubclass();
      expect(s.providePauseListeners(null), isEmpty);
    });

    test('provideResumeListeners defaults to const []', () {
      final s = _ForgetfulSubclass();
      expect(s.provideResumeListeners(null), isEmpty);
    });

    test(
      'AppLifecycleState.paused on a forgetful subclass transitions to '
      'PAUSE_SUCCESS instead of crashing',
      () async {
        final s = _ForgetfulSubclass();
        (await s.init().value).end();
        expect(s.state, ServiceState.RUN_SUCCESS);

        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        // Two microtask drains: one for `consec`'s callback, one for the
        // sequencer's pause completion.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(s.state, ServiceState.PAUSE_SUCCESS);

        (await s.dispose().value).end();
      },
    );

    test(
      'AppLifecycleState.paused → .resumed on a forgetful subclass cycles '
      'through PAUSE_SUCCESS → RESUME_SUCCESS',
      () async {
        final s = _ForgetfulSubclass();
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.paused);
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

  group('ObservedService: registerObserver / unregisterObserver idempotence',
      () {
    test('registerObserver is a no-op when already registered', () async {
      final s = _ForgetfulSubclass();
      (await s.init().value).end();
      expect(s.isObserverRegistered, isTrue);

      // Calling registerObserver a second time must not double-register and
      // must not throw — addObserver would be a duplicate but addObserver
      // itself silently appends; the idempotency guard prevents that.
      (await s.registerObserver().value).end();
      expect(s.isObserverRegistered, isTrue);

      (await s.dispose().value).end();
    });

    test('unregisterObserver before init is a no-op (does not throw)',
        () async {
      final s = _ForgetfulSubclass();
      expect(s.isObserverRegistered, isFalse);
      (await s.unregisterObserver().value).end();
      expect(s.isObserverRegistered, isFalse);
    });

    test(
      'unregisterObserver is a no-op after dispose; safe to call repeatedly',
      () async {
        final s = _ForgetfulSubclass();
        (await s.init().value).end();
        (await s.dispose().value).end();
        expect(s.isObserverRegistered, isFalse);

        (await s.unregisterObserver().value).end();
        expect(s.isObserverRegistered, isFalse);
      },
    );
  });

  group('ObservedService: lifecycle events ignored when not opted-in', () {
    test(
      'with default `=> false` handlers, AppLifecycleState.paused does not '
      'touch the service even if a child subclass forgot to override '
      'providePauseListeners',
      () async {
        // Same fixture as above, but we route through a path where the
        // forgetful subclass is wrapped in another that turns OFF the
        // opt-ins. The point: defaults must compose harmlessly.
        final s = _NonOptInSubclass();
        (await s.init().value).end();

        s.didChangeAppLifecycleState(AppLifecycleState.paused);
        s.didChangeAppLifecycleState(AppLifecycleState.resumed);
        s.didChangeAppLifecycleState(AppLifecycleState.hidden);
        s.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await Future<void>.delayed(Duration.zero);

        expect(s.state, ServiceState.RUN_SUCCESS);

        (await s.dispose().value).end();
      },
    );
  });
}

final class _NonOptInSubclass extends ObservedService {
  // Inherits the default `=> false` handlers from
  // HandleServiceLifecycleStateMixin AND the default `=> const []`
  // listener providers from ObservedService. Nothing overridden at all.
}

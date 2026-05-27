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

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// A [ServiceMixin]-based service that doubles as a [WidgetsBindingObserver]
/// for Flutter app-lifecycle events. Combined with
/// [HandleServiceLifecycleStateMixin], the service can auto-pause / resume /
/// dispose itself in response to `AppLifecycleState` changes.
///
/// The observer is registered/removed via [registerObserver] /
/// [unregisterObserver] (NOT in the constructor), so it works correctly even
/// if the service is constructed before `WidgetsFlutterBinding.ensureInitialized()`
/// and so that a failed `init` doesn't leak a global observer.
///
/// Subclasses that further mix in [StreamServiceMixin] (or its descendants)
/// must re-insert [registerObserver] / [unregisterObserver] in their own
/// `provideInitListeners` / `provideDisposeListeners` overrides — those
/// mixins do not chain through `super` to this base class.
abstract class ObservedService extends WidgetsBindingObserver
    with ServiceMixin, HandleServiceLifecycleStateMixin {
  ObservedService();

  bool _isObserverRegistered = false;

  /// Whether this service is currently registered as a
  /// [WidgetsBindingObserver]. Becomes `true` after [registerObserver] runs
  /// successfully and `false` after [unregisterObserver].
  @protected
  @visibleForTesting
  bool get isObserverRegistered => _isObserverRegistered;

  /// Adds this service as a global [WidgetsBindingObserver]. Idempotent —
  /// safe to call multiple times within a single lifetime.
  ///
  /// Returns an `Err` (instead of throwing) if `WidgetsBinding.instance` is
  /// not available — e.g. the caller invoked `init()` before
  /// `WidgetsFlutterBinding.ensureInitialized()`. This converts a Flutter
  /// framework throw into a structured listener failure that the service
  /// lifecycle can surface via [Log.err] and the resulting `RUN_ERROR` state.
  @protected
  @visibleForTesting
  Resolvable<Unit> registerObserver() {
    if (_isObserverRegistered) {
      return syncUnit();
    }
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (e, stackTrace) {
      return Sync<Unit>.err(
        Err(
          '$runtimeType.registerObserver: WidgetsBinding is not available. '
          'Call WidgetsFlutterBinding.ensureInitialized() before init(). '
          'Underlying error: $e',
          stackTrace: stackTrace,
        ),
      );
    }
    _isObserverRegistered = true;
    return syncUnit();
  }

  /// Removes this service as a global [WidgetsBindingObserver]. Idempotent —
  /// safe to call multiple times.
  ///
  /// If `WidgetsBinding.instance` is no longer reachable at dispose time the
  /// failure is logged (release-safe) and treated as already-unregistered;
  /// dispose listeners must never throw out of the service lifecycle.
  @protected
  @visibleForTesting
  Resolvable<Unit> unregisterObserver() {
    if (!_isObserverRegistered) {
      return syncUnit();
    }
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      Log.err(
        '$runtimeType.unregisterObserver: WidgetsBinding unavailable at '
        'teardown ($e). Treating observer as already removed.',
      );
    }
    _isObserverRegistered = false;
    return syncUnit();
  }

  @override
  @mustCallSuper
  TServiceResolvables<Unit> provideInitListeners(void _) {
    return [(_) => registerObserver()];
  }

  @override
  @mustCallSuper
  TServiceResolvables<Unit> provideDisposeListeners(void _) {
    return [(_) => unregisterObserver()];
  }

  /// Safe default: returns `const []`. Subclasses that need to do work on
  /// [pause] override this and call `super.providePauseListeners(null)`.
  ///
  /// Without this default a subclass that opts in to `handlePausedState() =>
  /// true` but forgets to override [providePauseListeners] would inherit the
  /// abstract declaration and crash in release the first time the app is
  /// paused. For safety-critical software the silent no-op is preferable to
  /// a release-time crash on a routine lifecycle event.
  @override
  @mustCallSuper
  TServiceResolvables<Unit> providePauseListeners(void _) => const [];

  /// Safe default: returns `const []`. See [providePauseListeners] for
  /// rationale; same considerations apply on resume.
  @override
  @mustCallSuper
  TServiceResolvables<Unit> provideResumeListeners(void _) => const [];
}

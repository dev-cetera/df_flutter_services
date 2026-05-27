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

import 'package:df_di/df_di.dart';
import 'package:df_log/df_log.dart';
import 'package:df_safer_dart/_common.dart';

import 'package:flutter/widgets.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Bridges Flutter's [AppLifecycleState] → [ServiceMixin] lifecycle calls.
/// Each `handleXState` hook is opt-in: override to return `true` and the
/// corresponding service method ([pause]/[resume]/[dispose]) is invoked when
/// the app enters that state.
mixin HandleServiceLifecycleStateMixin on WidgetsBindingObserver, ServiceMixin {
  //
  //
  //

  /// Return `true` to have the service [pause] when the app enters
  /// [AppLifecycleState.paused]. Defaults to `false` (opt-in).
  @visibleForOverriding
  bool handlePausedState() => false;

  /// Return `true` to have the service [resume] when the app enters
  /// [AppLifecycleState.resumed]. Defaults to `false` (opt-in).
  @visibleForOverriding
  bool handleResumedState() => false;

  /// Return `true` to have the service [pause] when the app enters
  /// [AppLifecycleState.hidden]. Defaults to `false` (opt-in).
  @visibleForOverriding
  bool handleHiddenState() => false;

  /// Return `true` to have the service [pause] when the app enters
  /// [AppLifecycleState.inactive]. Defaults to `false` (opt-in).
  @visibleForOverriding
  bool handleInactiveState() => false;

  /// Return `true` to have the service [dispose] when the app enters
  /// [AppLifecycleState.detached]. Defaults to `false` (opt-in).
  @visibleForOverriding
  bool handleDetachedState() => false;

  //
  //
  //

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Defensive: drop the event entirely if the service is already disposed.
    // Normally the observer is removed during dispose so Flutter never
    // delivers events past that point, but a stale reference or a direct
    // call could still arrive — routing through pause/resume/dispose would
    // only produce a noisy post-terminal Err (plus an `assert(false, ...)`
    // in debug). Silently dropping the event matches the spirit of
    // df_di's terminal-state contract.
    if (this.state.didDispose()) return;
    switch (state) {
      case AppLifecycleState.paused:
        if (handlePausedState()) {
          _runBridge('pause', state, pause());
        }
        break;
      case AppLifecycleState.resumed:
        if (handleResumedState()) {
          _runBridge('resume', state, resume());
        }
        break;
      case AppLifecycleState.hidden:
        if (handleHiddenState()) {
          _runBridge('pause', state, pause());
        }
        break;
      case AppLifecycleState.inactive:
        if (handleInactiveState()) {
          _runBridge('pause', state, pause());
        }
        break;
      case AppLifecycleState.detached:
        if (handleDetachedState()) {
          _runBridge('dispose', state, dispose());
        }
        break;
    }
  }

  /// Shared error/log path for every lifecycle bridge. Centralises the
  /// release-safe `Log.err` + debug-only `assert(false, ...)` pattern so each
  /// case in [didChangeAppLifecycleState] stays small and the log message
  /// format is consistent — important for crash-report triage in production
  /// builds where the stack trace is the only signal a reader has.
  void _runBridge(
    String phase,
    AppLifecycleState appState,
    Resolvable<Unit> task,
  ) {
    // `ifErr` on an `Async` returns a NEW lazy Async whose body only runs
    // when something pulls on its value — so the trailing `.end()` is load-
    // bearing, not stylistic. Without it the Async path silently drops the
    // log + assert on listener failure. `Sync.ifErr` runs eagerly, and
    // `Sync.end()` is a no-op, so the same call works for both cases.
    task.ifErr((self, err) {
      Log.err(
        '$runtimeType.$phase() failed on AppLifecycleState.${appState.name}: '
        '${err.error}',
      );
      assert(false, err);
    }).end();
  }
}

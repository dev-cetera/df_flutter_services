//.title
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//
// Dart/Flutter (DF) Packages by dev-cetera.com & contributors. The use of this
// source code is governed by an MIT-style license described in the LICENSE
// file located in this project's root directory.
//
// See: https://opensource.org/license/mit
//
// ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
//.title~

import 'package:df_di/df_di.dart';
import 'package:df_log/df_log.dart';

import 'package:flutter/widgets.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mixin HandleServiceLifecycleStateMixin on WidgetsBindingObserver, ServiceMixin {
  //
  //
  //

  bool handlePausedState() => false;

  bool handleResumedState() => false;

  bool handleHiddenState() => false;

  bool handleInactiveState() => false;

  bool handleDetachedState() => false;

  //
  //
  //

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (handlePausedState()) {
          consec(resume().value, (result) {
            if (result.isErr()) {
              Log.err('pause() failed on ${AppLifecycleState.paused.name}!');
              assert(false, result.err().unwrap());
            }
          });
        }
        break;
      case AppLifecycleState.resumed:
        if (handleResumedState()) {
          consec(resume().value, (result) {
            if (result.isErr()) {
              Log.err('resume() failed on ${AppLifecycleState.resumed.name}!');
              assert(false, result.err().unwrap());
            }
          });
          break;
        }
      case AppLifecycleState.hidden:
        if (handleHiddenState()) {
          consec(pause().value, (result) {
            if (result.isErr()) {
              Log.err('pause() failed on ${AppLifecycleState.hidden.name}!');
              assert(false, result.err().unwrap());
            }
          });
        }
        break;
      case AppLifecycleState.inactive:
        if (handleInactiveState()) {
          consec(pause().value, (result) {
            if (result.isErr()) {
              Log.err('pause() failed on ${AppLifecycleState.inactive.name}!');
              assert(false, result.err().unwrap());
            }
          });
        }
        break;
      case AppLifecycleState.detached:
        if (handleDetachedState()) {
          consec(dispose().value, (result) {
            if (result.isErr()) {
              Log.err(
                'dispose() failed on ${AppLifecycleState.detached.name}!',
              );
              assert(false, result.err().unwrap());
            }
          });
        }
        break;
    }
  }
}

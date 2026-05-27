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

/// An [ObservedService] that also owns a [StreamServiceMixin]-backed broadcast
/// stream. The stream is paused/resumed in step with the Flutter app lifecycle
/// when the matching `handleXState` hooks are opted in.
abstract class ObservedStreamService<TData extends Object>
    extends ObservedService with StreamServiceMixin<TData> {
  ObservedStreamService() : super();

  // StreamServiceMixin.provideInitListeners / .provideDisposeListeners do not
  // call `super`, so ObservedService's observer-registration listeners would
  // never run via the mixin chain. Re-insert them here explicitly.

  @override
  TServiceResolvables<Unit> provideInitListeners(void _) {
    return [
      (_) => registerObserver(),
      ...super.provideInitListeners(null),
    ];
  }

  @override
  TServiceResolvables<Unit> provideDisposeListeners(void _) {
    return [
      ...super.provideDisposeListeners(null),
      (_) => unregisterObserver(),
    ];
  }
}

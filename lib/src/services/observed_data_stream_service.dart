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

/// An [ObservedService] that also owns a single pod ([pData]) reflecting the
/// latest emission from its stream. Combines [StreamServiceMixin] with
/// [HandleServiceLifecycleStateMixin] (inherited from [ObservedService]) so
/// the stream pauses/resumes alongside the Flutter app lifecycle.
abstract class ObservedDataStreamService<TData extends Object>
    extends ObservedService
    with StreamServiceMixin<TData>, ObservedDataStreamServiceMixin<TData> {
  ObservedDataStreamService() : super();

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

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

/// Adds a single [pData] pod that mirrors the latest stream emission. The pod
/// is cleared (not disposed) on dispose so consumers caching its reference
/// continue to work across re-init cycles (e.g. relogin).
mixin ObservedDataStreamServiceMixin<TData extends Object>
    on ServiceMixin, StreamServiceMixin<TData> {
  //
  //
  //

  /// The latest stream emission, wrapped in [Option] (`None` before the first
  /// emission, `Some(Result<TData>)` afterwards). Survives `dispose → init`
  /// cycles — dispose clears it back to `None` instead of disposing the pod.
  final RootPod<Option<Result<TData>>> pData = Pod<Option<Result<TData>>>(
    const None(),
  );

  //
  //
  //

  @mustCallSuper
  @override
  TServiceResolvables<Unit> provideInitListeners(void _) {
    return [
      ...super.provideInitListeners(null),
      (_) {
        if (!pData.isDisposed) {
          pData.set(const None());
        }
        return syncUnit();
      },
    ];
  }

  @mustCallSuper
  @override
  TServiceResolvables<Unit> provideDisposeListeners(void _) {
    return [
      (_) {
        if (!pData.isDisposed) {
          pData.set(const None());
        }
        return syncUnit();
      },
      ...super.provideDisposeListeners(null),
    ];
  }

  @mustCallSuper
  @override
  TServiceResolvables<Result<TData>> provideOnPushToStreamListeners() {
    return [
      (data) {
        // Guard against late listener execution: a push initiated before
        // dispose can still reach this listener after dispose ran (pushes
        // run on a separate sequencer from the lifecycle one). Without this
        // check, that late landing would re-set pData to Some(...) after the
        // dispose listener cleared it to None.
        if (state.didDispose() || pData.isDisposed) {
          return syncUnit();
        }
        pData.set(Some(data));
        return syncUnit();
      },
    ];
  }
}

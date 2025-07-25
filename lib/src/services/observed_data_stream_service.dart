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

abstract class ObservedDataStreamService<TData extends Object> extends WidgetsBindingObserver
    with
        ServiceMixin,
        StreamServiceMixin<TData>,
        ObservedDataStreamServiceMixin<TData>,
        HandleServiceLifecycleStateMixin {
  ObservedDataStreamService() {
    WidgetsBinding.instance.addObserver(this);
  }
}

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mixin ObservedDataStreamServiceMixin<TData extends Object>
    on ServiceMixin, StreamServiceMixin<TData> {
  //
  //
  //

  final RootPod<Option<Result<TData>>> pData = Pod<Option<Result<TData>>>(const None());

  //
  //
  //

  @mustCallSuper
  @override
  TServiceResolvables<Unit> provideInitListeners(void _) {
    return [
      ...super.provideInitListeners(null),
      (_) {
        pData.set(const None());
        return syncUnit();
      },
    ];
  }

  @mustCallSuper
  @override
  TServiceResolvables<Unit> provideDisposeListeners(void _) {
    return [
      (_) {
        pData.dispose();
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
        pData.set(Some(data));
        return syncUnit();
      },
    ];
  }
}

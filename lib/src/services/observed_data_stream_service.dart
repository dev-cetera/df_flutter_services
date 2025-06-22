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

import '/_common.dart';

// ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

abstract base class DataStreamService<TData extends Object> extends WidgetsBindingObserver
    with ServiceMixin, StreamServiceMixin<TData>, HandleServiceLifecycleStateMixin {
  //
  //
  //

  final pData = Pod<Option<Result<TData>>>(const None());

  //
  //
  //

  DataStreamService() {
    WidgetsBinding.instance.addObserver(this);
  }

  //
  //
  //

  @mustCallSuper
  @override
  provideInitListeners(void _) {
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
  provideDisposeListeners(void _) {
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
  provideOnPushToStreamListeners() {
    return [
      (data) {
        pData.set(Some(data));
        return syncUnit();
      },
    ];
  }
}

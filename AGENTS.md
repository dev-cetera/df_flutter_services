# CLAUDE.md — df_flutter_services

Working notes for AI agents collaborating on this package.

## Role in the state-management stack

`df_flutter_services` is the **Flutter-integration layer** — the top of the four-package state-management stack. It glues `df_di`'s service lifecycle to Flutter's `WidgetsBindingObserver` and provides the `pData : Pod<Option<Result<T>>>` pattern that every screen subscribes to. The full stack lives in `/Users/robmllze/Projects/flutter/dev_cetera/df_packages/packages/`:

| Package | Path | Role |
| --- | --- | --- |
| `df_safer_dart` | `../df_safer_dart` | Foundation: `Option<T>`, `Result<T>`, `Resolvable<T>`, `Outcome<T>`, `UNSAFE`, `SafeCompleter`, `TaskSequencer` |
| `df_di` | `../df_di` | DI container hierarchy (`DI.root`/`global`/`session`/`user`), `Service`/`ServiceMixin`, `StreamServiceMixin`, `PollingStreamServiceMixin` |
| `df_pod` | `../df_pod` | Reactive containers (`Pod<T>`, `ChildPod`, `ReducerPod`, `SharedPod`), `WeakChangeNotifier`, `PodBuilder` and friends |
| `df_flutter_services` *(this)* | `.` | `ObservedService`, `ObservedStreamService`, `ObservedDataStreamService`, `ObservedPollingStreamService`, `HandleServiceLifecycleStateMixin`, `ObservedDataStreamServiceMixin` |

`pubspec_overrides.yaml` pins all siblings to local paths.

## State-management guide

Read **`doc/state_management_approach.md`** when you need the whole picture (how Pods live on services, how DI scopes hold them, how Flutter lifecycle integrates, the `G` singleton pattern, login/logout flow, common pitfalls). The same file is mirrored in every package of the stack (`df_safer_dart`, `df_di`, `df_pod`, `df_flutter_services`) — keep the copies in sync when editing.

## What lives in this package (`lib/src/services/`)

- `observed_service.dart` — `ObservedService`: `ServiceMixin` + `WidgetsBindingObserver` + `HandleServiceLifecycleStateMixin`. The observer is registered/removed in init/dispose listeners (NOT in the constructor), so it's safe to construct before `WidgetsFlutterBinding.ensureInitialized()` and a failed init doesn't leak a global observer.
- `observed_stream_service.dart` — `ObservedService` + `StreamServiceMixin<TData>`.
- `observed_data_stream_service.dart` — adds the `pData : Pod<Option<Result<TData>>>` mirror that survives `dispose → init` cycles (cleared to `None`, not disposed) so callers caching the reference keep working across relogin.
- `observed_polling_stream_service.dart` — `ObservedService` + `PollingStreamServiceMixin<TData>`.
- `handle_service_lifecycle_state_mixin.dart` — five opt-in hooks (`handlePausedState` / `handleResumedState` / `handleHiddenState` / `handleInactiveState` / `handleDetachedState`) mapping `AppLifecycleState` → `pause()` / `resume()` / `dispose()`.

## Conventions specific to df_flutter_services

- `ObservedService` supplies safe defaults: `providePauseListeners` and `provideResumeListeners` both default to `=> const []`. Subclasses that need pause/resume work override and call `super.providePauseListeners(null)` to compose. The previous "subclasses must implement or the app crashes" rule is gone — leaving these defaulted is now a deliberate, safe no-op for safety-critical software.
- Override `handleXxxState() => true` to opt into the corresponding lifecycle bridging. Defaults are all `false`.
- `pData` is meant to outlive a single init/dispose cycle. Do **not** call `pData.dispose()` from a custom `provideDisposeListeners`; the mixin's own listener clears it to `None`.
- When extending `ObservedDataStreamService` and overriding `provideDisposeListeners` / `provideInitListeners`, call `super.provideXxxListeners(null)` and prepend/append. The mixin's listener for `pData` must run.
- Lifecycle-bridge errors are logged via `Log.err(...)` (release-safe) including `$runtimeType.$phase()` and the `AppLifecycleState.name`, then re-asserted via `assert(false, ...)` (debug-only). The release log carries enough identity to triage from a crash report alone.
- `registerObserver()` returns `Err` (instead of throwing) if `WidgetsBinding.instance` is unavailable — typically because `init()` ran before `WidgetsFlutterBinding.ensureInitialized()`. The service transitions to `RUN_ERROR` cleanly rather than blowing up with a Flutter framework exception.

## Tests (`test/`)

- `observed_data_stream_service_test.dart` — `pData` mirror correctness across emissions, error paths, dispose/clear semantics, and DI integration (`registerAndInitService` + `unregister` round-trip).
- `handle_service_lifecycle_state_mixin_test.dart` — opt-in handler defaults, pause/resume/dispose forwarding from `didChangeAppLifecycleState`.
- `observer_registration_test.dart` — observer is registered on init and unregistered on dispose across every concrete subclass; pData-dispose race regression.
- `safety_defaults_test.dart` — safe `=> const []` defaults for pause/resume listeners; idempotence of register/unregister; lifecycle events on a fully default subclass.

```bash
flutter test                                    # all
flutter test test/observed_data_stream_service_test.dart
flutter test --plain-name "pData starts as None"
```

## Recent breaking work

- **0.2.0**: Bumped dependency constraints to the workspace majors (`df_di ^0.16`, `df_pod ^0.20`, `df_safer_dart ^0.18`, `df_log ^0.5`, `df_type ^0.15`, dev `df_safer_dart_lints ^0.4`). The previous `^0.18.11` / `^0.3.29` constraints were incompatible with the currently-published versions of `df_pod` / `df_log`. Added `test/` coverage (was zero before this).

## Frequent gotcha for new subclasses

If you write a subclass that just observes Flutter lifecycle but doesn't need any pause/resume work, the minimum boilerplate is:

```dart
final class MyService extends ObservedService {
  @override
  bool handlePausedState()  => true;
  @override
  bool handleResumedState() => true;

  // providePauseListeners / provideResumeListeners are NOT required —
  // ObservedService supplies safe `=> const []` defaults. Override only
  // when you actually need to run something on pause/resume, and remember
  // to chain through `super` when you do:
  //
  //   @override
  //   TServiceResolvables<Unit> providePauseListeners(void _) => [
  //     ...super.providePauseListeners(null),
  //     (_) => doSomethingOnPause(),
  //   ];
}
```

That's the typical shape in `hup-app`, `heylang`, and `jobxcel`.

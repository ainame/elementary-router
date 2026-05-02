# TODO

このリポジトリは pre-release なので、過去の一時 API との互換は守らない。  
最終的に欲しい API 形に向けて、壊してでも実装を寄せる。

## 現時点の結論

- `RouterView` の本命は、runtime `AnyView` ではなく macro 生成の typed route view union にする。
- ユーザー向け route 定義は `@Routes` を中心にする。手書きの `AppRouteView` enum は許容しない。
- `RouteCollection` / `RouteTree` / `Router` / `RouterView` は、最終的に `RouteContent: View` を型として持つ generic API に寄せる。
- vendored ElementaryUI の `AnyView` spike は学習用としては有効だが、本線にはしない。SSR/text rendering/identity/state preservation を ElementaryUI 側で完全に解く必要があり、router の理想 API を先に進めるには重すぎる。
- 新方式へ移行するときは vendor のお試し実装 spike をすべて消し、ElementaryRouter は upstream の ElementaryUI package を使う形へ戻す。vendor submodule は最終実装に残さない。
- `Link` の完全な client navigation interception には ElementaryUI 側の event API 追加が必要。今の `MouseEvent` は modifier/button 判定はできるが、`preventDefault()` を public に呼べない。

## 実装済みの初期スライス

- vendor の ElementaryUI submodule と `.gitmodules` を削除し、root package と example package を upstream ElementaryUI dependency に戻した。
- `RouteCollection` / `RouteTree` / `Router` を `RouteContent: View` generic に変更し、runtime `AnyView` 依存を ElementaryRouter から外した。
- `@Routes`, `@Route`, `@NotFound`, `@RouteError` の macro target と public macro declarations を追加した。
- `@Routes` から `RouteView`, `Handles`, `RouteSet`, `routes()` を生成する最小実装を追加した。
- `Examples/RouterExample` を `@Routes` ベースに移行した。
- test target で `@Routes` 生成の `RouteSet` と typed route view を直接検証するテストを追加した。

## 調査済みの制約

- ElementaryUI の `@View` macro はドキュメント上も実装上も struct に付ける前提。
  - `@Routes` が生成する route view は `enum: View` ではなく、`@View struct RouteView { enum Storage { ... } }` か、同等の `__FunctionView` conformance を生成する形にする。
  - macro が生成した declaration に付いた `@View` が再展開されるかは実証が必要。再展開されない場合、`@Routes` macro 側で ElementaryUI の function-view conformance も生成する。
- ElementaryUI の `View` は associated type と mount node を持つため、通常の existential では route ごとに異なる concrete view を安全に保持できない。
- 現在の vendored `AnyView` spike は CSR mount/patch だけを狙ったもので、text rendering と SSR は未対応。さらに type identity を簡略化しているため、同型 route view の state preservation も最終仕様としては弱い。
- 現在の `RoutePattern` は literal、`:parameter`、`*` wildcard、duplicate parameter check、path build を持っている。macro はこの仕様を前提にしつつ、compile-time diagnostics を足す。
- 現在の `RouteParameters` は `String` / `Int` / `Double` / `Bool` の typed parse を持っている。macro は route function parameter の型から `RouteParameters.require(_:_: )` を生成する。
- `Link` は `onClick` で `button` と modifier keys は見られるが、default anchor navigation を止められない。ElementaryUI に `MouseEvent.preventDefault()` か cancellable event handler が必要。

## 1. `@Routes` macro を設計して導入する

目標 API:

```swift
@Routes
struct AppRoutes {
  @Route("/")
  static func home() -> HomePage {
    HomePage()
  }

  @Route("/:lang/profile/:profileId")
  static func profile(
    lang: String,
    profileId: Int,
    tab: Query<String> = "overview"
  ) -> ProfilePage {
    ProfilePage(lang: lang, profileID: profileId, tab: tab.value)
  }

  @Route("/docs/*")
  static func docs(splat: Wildcard) -> DocsPage {
    DocsPage(slug: splat.value)
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
    NotFoundPage(path: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> InvalidRoutePage {
    InvalidRoutePage(error: context.error)
  }
}
```

Generated shape:

```swift
extension AppRoutes {
  @View
  struct RouteView {
    enum Storage {
      case home
      case profile(lang: String, profileId: Int, tab: String)
      case docs(splat: String)
      case notFound(RouteNotFoundContext)
      case routeError(RouteErrorContext)
    }

    let storage: Storage

    var body: some View {
      switch storage {
      case .home:
        AppRoutes.home()
      case .profile(let lang, let profileId, let tab):
        AppRoutes.profile(lang: lang, profileId: profileId, tab: Query(tab))
      case .docs(let splat):
        AppRoutes.docs(splat: Wildcard(splat))
      case .notFound(let context):
        AppRoutes.notFound(context: context)
      case .routeError(let context):
        AppRoutes.routeError(context: context)
      }
    }
  }

  static func routes() throws(RouteTreeError) -> RouteTree<RouteView> { ... }
}
```

実装タスク:

- Add `ElementaryRouterMacros` target and macro declarations.
- Add `CompilerPluginSupport` and SwiftSyntax dependencies to `Package.swift`.
- Define attached macros:
  - `@Routes` on a `struct`.
  - `@Route(_ path: String)` on `static func`.
  - `@NotFound` on one `static func`.
  - `@RouteError` on one `static func`.
- Generate a typed `RouteView` wrapper and route table from route declarations.
- Verify whether generated `@View struct` expands correctly.
- If generated `@View` does not expand, generate `View` / `__FunctionView` support directly or ask ElementaryUI for a public macro-composition hook.
- Add macro expansion tests for happy paths and diagnostics.

Diagnostics to implement:

- `@Routes` can only attach to a `struct`.
- `@Route` can only attach to `static func`.
- Route path must be a string literal.
- Path params must match function parameter names.
- Typed path params must conform to `RouteValue`.
- Wildcard must be represented explicitly, likely by `Wildcard` or a reserved `splat` parameter.
- Duplicate normalized paths are compile-time errors when statically visible.
- Multiple `@NotFound` or `@RouteError` declarations are errors.
- Unsupported route function shapes produce actionable diagnostics.

Open design points:

- Choose final query parameter spelling: `Query<T>`, `Query<T?>`, `Query<[T]>`, or parameter attributes.
- Decide whether route declarations may throw, or whether parse failures are the only route render errors.
- Decide generated handle names, for example `AppRoutes.handles.profile` vs `AppRoutes.profileRoute`.
- Decide whether generated code should preserve declaration order for equal specificity.

## 2. Remove runtime `AnyView` from ElementaryRouter

Target runtime shape:

```swift
public struct RouteTree<RouteContent: View> { ... }
public final class Router<RouteContent: View> { ... }

@View
public struct RouterProvider<RouteContent: View, Content: View> { ... }

@View
public struct RouterView<RouteContent: View> { ... }
```

Implementation tasks:

- Replace `RouteCollection` renderer storage from `AnyView` closures to `(RouteContext) throws(RouteValueError) -> RouteContent`.
- Make `RouteTree.render(_:) -> RouteContent`.
- Make `Router.renderCurrentRoute() -> RouteContent`.
- Make `RouterProvider` carry `Router<RouteContent>`.
- Make `RouterView` read the typed router from environment and return `RouteContent`.
- Delete the fallback `AnyView(EmptyHTML())` behavior from `RouterView`; missing router should be a programmer error or an explicit empty route content decided by the generated route table.
- After macro path works, remove the vendored ElementaryUI `AnyView` spike from the final dependency path.

## 3. Redesign nested layout rendering as typed static composition

Goal:

- `Router.matches` remains the parent-to-leaf stack.
- Parent layout routes render around child route content.
- The generated `RouteView` should keep parent layout identity stable across sibling child navigations where ElementaryUI can reconcile it.
- Fallback/error policy stays in route/router configuration, not inside page `body`.

Likely API direction:

```swift
@Routes
struct AppRoutes {
  @Layout("/:lang")
  static func languageLayout(lang: String, outlet: Outlet) -> LanguageLayout {
    LanguageLayout(lang: lang, outlet: outlet)
  }

  @Route("/:lang/profile/:profileId")
  static func profile(lang: String, profileId: Int) -> ProfilePage {
    ProfilePage(lang: lang, profileID: profileId)
  }
}
```

Tasks:

- Decide whether `@Layout` is a separate macro or `@Route(..., layout: true)`.
- Define `Outlet` as a typed generated value, not a runtime erased view.
- Generate nested switches grouped by layout route, rather than always switching only at the leaf.
- Define index route behavior under layouts.
- Define how parent route parse errors select route-level or router-level error views.
- Add tests for parent-to-leaf render order, layout preservation, index routes, wildcard children, and layout error handling.

## 4. Finalize route handles and typed href generation

Goals:

- Users should not manually construct `RouteHandle`.
- Generated handles should be stable within the route set and ergonomic for `Link` / navigation.
- URL generation should be typed where macro information is available.

Tasks:

- Keep `RouteID` and `RouteHandle` construction internal to registration/generated code.
- Generate route-specific href helpers, for example:

  ```swift
  router.href(to: AppRoutes.handles.profile, lang: "ja", profileId: 42, query: .init(tab: "posts"))
  ```

- Decide whether typed helpers live on `Router`, `AppRoutes`, or a generated `Navigator`.
- Keep lower-level `RouteParameters` APIs for dynamic cases, tests, and non-macro route tables.
- Add active matching options:
  - exact route
  - descendant route
  - path params
  - query params
  - hash

## 5. Complete `Link` navigation semantics

Current blocker:

- ElementaryUI exposes click information but not `preventDefault()`.

Required ElementaryUI-side API:

```swift
extension MouseEvent {
  public func preventDefault()
}
```

or:

```swift
consuming func onClick(_ handler: @escaping (MouseEvent) -> EventDisposition) -> some View<Tag>
```

Router tasks after that exists:

- Intercept only same-origin, left-click, no-modifier, no-target, non-download navigation.
- Call `preventDefault()` before router navigation for eligible clicks.
- Preserve native browser behavior for modifier clicks, external URLs, downloads, and targets.
- Always render a meaningful `href`.
- Support typed generated route handles and typed params.
- Add tests for click eligibility logic using a pure helper independent of JavaScriptKit.

## 6. Error and not-found policy

Goals:

- Matching failure renders a configured not-found route content.
- Param/query decode failure renders the nearest route-level error content, then router-level error content.
- Errors do not require page views to branch inside their `body`.

Tasks:

- Make generated route table include explicit not-found and error cases in `RouteView.Storage`.
- Add route-level error declarations if needed:

  ```swift
  @RouteError(for: profile)
  static func profileError(context: RouteErrorContext) -> ProfileErrorPage { ... }
  ```

- Decide whether route render functions can throw arbitrary errors. Prefer keeping errors typed until there is a concrete loader story.
- Add tests for missing params, invalid typed params, query parse failures, not found, and parent layout errors.

## 7. Embedded Swift and WASM hardening

Tasks:

- Keep production sources free of `Foundation`.
- Avoid public APIs that require existential view storage for core routing.
- Avoid fragile core references such as `weak` in router state.
- Add an example build that exercises generated `@Routes` code under Swift/WASM.
- Add a small Embedded Swift compatibility target or documented smoke test if the toolchain can build it reliably.
- Keep browser integration behind `BrowserHistory`, `MemoryHistory`, and `HashHistory`.
- Keep JavaScriptKit usage out of route parsing and route matching.

## 8. Documentation and examples

Tasks:

- Rewrite `README.md` around `@Routes`.
- Rewrite `Examples/RouterExample` to use generated `AppRoutes.routes()`.
- Document:
  - `@Routes`
  - `@Route`
  - `@Layout`
  - `@NotFound`
  - `@RouteError`
  - generated route handles
  - `RouterProvider`
  - `RouterView`
  - `Link`
  - `RouteParameters` for dynamic escape hatches
- Keep `LEARNING.md` as background notes, but make `README.md` describe the final API rather than the spike history.
- Either remove `Docs/RouterViewRendering.md` or mark it explicitly as an archived spike once the typed macro approach lands.

## 9. Cleanup required for the macro route path

Tasks:

- Remove ElementaryRouter's dependency on vendored `AnyView`.
- Remove the `vendor/elementary-ui` submodule and `.gitmodules` entry.
- Revert `Package.swift` and `Examples/RouterExample/Package.swift` to upstream ElementaryUI package dependencies.
- Regenerate `Package.resolved` files for upstream ElementaryUI.
- Do not carry local ElementaryUI spike patches in the final macro-route implementation.
- If ElementaryUI changes are still needed, open them as upstream ElementaryUI changes first and consume them through the upstream dependency after they are available there.
- Delete route builder APIs that encourage heterogeneous runtime views if they conflict with the macro-first model.
- Remove compatibility aliases and temporary placeholder APIs.

## Validation

For Swift/source changes:

```sh
swift-format lint --configuration .swift-format Package.swift Sources Tests Examples/RouterExample/Package.swift Examples/RouterExample/Sources --recursive --parallel
swift test
cd Examples/RouterExample && swift build
cd Examples/RouterExample && npm run build
```

For macro work, also add and run macro expansion tests.  
For Markdown-only changes, Swift builds are not required unless executable snippets or package names change.

# TODO

このリポジトリは pre-release なので、過去の一時 API との互換は守らない。  
現在の実装方針は、runtime `AnyView` ではなく `@Routes` macro が生成する typed route view union を使うこと。

## 完了

- vendor の ElementaryUI submodule と `.gitmodules` を削除した。
- root package と example package を upstream `elementary-ui` dependency に戻した。
- `RouteCollection` / `RouteTree` / `Router` / `RouterProvider` / `RouterView` を `RouteContent: View` generic に移行した。
- ElementaryRouter から runtime `AnyView` 依存を外した。
- `@Routes`, `@Route`, `@Layout`, `@NotFound`, `@RouteError` を追加した。
- `@Routes` から `RouteView`, `Handles`, `RouteSet`, `routes()` を生成するようにした。
- `Query<T>` route parameters と `Wildcard` を追加した。
- route-specific href helpers を生成するようにした。
- macro diagnostics を追加した。
  - `@Routes` は struct のみ。
  - `@Route` / `@Layout` / fallback declarations は static function のみ。
  - route path は string literal のみ。
  - path params と function params の不一致を診断。
  - wildcard route と `Wildcard` parameter の不一致を診断。
  - duplicate route / duplicate fallback declarations を診断。
- `@Layout` と `Outlet<Content>` による typed nested layout composition を追加した。
- `Router.matches` は parent-to-leaf match stack を維持する。
- `Router.isActive(_:options:)` と `ActiveMatchOptions` を追加した。
- `LinkClick` の pure eligibility 判定を追加した。
- `Link` は left-click/no-modifier/self-target のみ router navigation するよう判定する。
- `Examples/RouterExample` を `@Routes` / `@Layout` ベースに移行した。
- `README.md`, `Examples/RouterExample/README.md`, `LEARNING.md` を現在の方針に合わせた。
- macro expansion tests と runtime tests を追加した。
- Swift package tests, example build, WASM/Vite build で検証した。

## 残る外部ブロッカー

ElementaryRouter 側で実装できる範囲は完了。完全な client-side navigation interception だけは ElementaryUI 側の public event API が必要。

必要な ElementaryUI API:

```swift
extension MouseEvent {
  public func preventDefault()
}
```

または:

```swift
consuming func onClick(_ handler: @escaping (MouseEvent) -> EventDisposition) -> some View<Tag>
```

この API が入った後に ElementaryRouter 側で行うこと:

- eligible click で `preventDefault()` を呼ぶ。
- modifier click, non-left click, `_blank` などの non-self target はブラウザ native のままにする。
- `LinkClick` tests に `preventDefault` 呼び出し有無の adapter test を追加する。

## 今後の改善候補

- `Query<T?>` と multi-value query の macro syntax を設計する。
- route-level `@RouteError(for:)` を追加する。
- nested layouts の index route 表現を追加する。
- generated href helper の命名と配置を利用例から再評価する。
- active matching の exact/descendant/query/hash semantics を README に詳述する。
- ElementaryUI に正式な `AnyView` が入った場合でも、router の本線は typed macro route view を維持する。

## Validation

```sh
swift-format lint --configuration .swift-format Package.swift Sources Tests Examples/RouterExample/Package.swift Examples/RouterExample/Sources --recursive --parallel
swift test
cd Examples/RouterExample && swift build
cd Examples/RouterExample && npm run build
```

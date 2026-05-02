# RouterView / AnyView 実験の学び

## 背景

`RouterView` を本当に描画できるようにするには、URL に応じて異なる concrete `View` を実行時に切り替える必要がある。

通常の ElementaryUI の `body` は `some View` を返すため、戻り値の concrete type はコンパイル時に 1 つへ決まる。

```swift
var body: some View {
  HomePage()
}
```

一方で router は URL によって返す view が変わる。

```swift
if path == "/" {
  HomePage()
} else if path == "/profile" {
  ProfilePage()
} else {
  NotFoundPage()
}
```

`HomePage`, `ProfilePage`, `NotFoundPage` はそれぞれ別の concrete type なので、そのままでは `some View` として保持・返却できない。この問題を解くには `AnyView` のような type-erased view abstraction が必要になる。

## なぜ ElementaryUI 側の対応が必要か

`elementary-router` 側だけで安全に解決するのは難しい。

ElementaryUI には内部的に `AnyReconcilable`, `MountContainer`, `_KeyedNode` など、異なる mounted node を扱う仕組みがある。ただしこれらは router package から使うための公開 API ではない。

公開 API だけでやる代替案として route ごとに nested `Application` を mount することも考えられるが、通常の view tree とは別ツリーになるため、environment、state、lifecycle、diffing の意味がずれる。router の基本機能として採用するには不自然。

したがって、正攻法は ElementaryUI 側に一般用途の type-erased view を追加すること。

```swift
public struct AnyView: View {
  public init<Content: View>(_ content: Content)
}
```

これは router 専用 API ではなく、「実行時に child view を選びたい container」のための ElementaryUI の基盤機能として扱うべき。

## 今回の vendor spike で確認できたこと

`vendor/elementary-ui` を submodule として追加し、実験用 `AnyView` を実装した。

確認できたこと:

- `AnyView` 経由で異なる concrete route view を `RouterView` から返せる
- ElementaryUI の通常の mount path に乗せられる
- `RouterView` は placeholder ではなく selected leaf route の view を返せる
- `swift test`, example の `swift build`, WASM/Vite の `npm run build` は通せた

ただし、この spike は本番品質の `AnyView` ではない。

現在の制限:

- CSR の mount/patch 実験用であり、HTML text rendering / SSR は未対応
- Embedded Swift 対応のため type-based identity を諦め、instance key を使っている
- そのため route switch 時は state preserving patch ではなく remount 寄りになる
- nested layout / `Outlet` の composition はまだ未実装

## CSR mount/patch と text rendering / SSR の違い

CSR は Client-Side Rendering のこと。Swift/WASM がブラウザ上で動き、DOM を直接作成・更新する。

- mount: 最初に DOM node を作って画面に差し込む
- patch: 状態や URL の変化に応じて既存 DOM を差分更新する

text rendering は view から HTML 文字列を作る経路。

```html
<section><h1>Home</h1></section>
```

SSR は Server-Side Rendering のことで、サーバー側で HTML 文字列を生成してブラウザへ返す。

ElementaryUI の `View` は `HTML` でもあるため、本来は DOM mount だけでなく HTML 文字列への rendering もサポートする必要がある。正式な `AnyView` は CSR と SSR の両方を扱えなければ、ElementaryUI の機能をフルには満たせない。

## Embedded Swift が難しくする点

Embedded Swift 対応を前提にすると、`AnyView` の実装難度がかなり上がる。

### Runtime reflection が使いづらい

通常の Swift なら erased view の identity に次のようなものを使いたくなる。

```swift
String(reflecting: Content.self)
ObjectIdentifier(Content.self)
```

しかし Embedded Swift ではこの種の metatype / reflection が制限される。今回の spike でも `String(reflecting:)` と `ObjectIdentifier(Content.self)` は WASM Embedded build で使えなかった。

つまり「同じ concrete view type なら patch、違う type なら remount」という判定を runtime type から簡単には作れない。

### Generic virtual method が使えない

HTML text rendering を type erase しようとすると、box class に generic method を持たせたくなる。

```swift
class Box {
  func render<R: _HTMLRendering>(into renderer: inout R) { ... }
}
```

しかし Embedded Swift では class の non-final generic method が禁止される。したがって `_AnyViewBox.render<Renderer>` のような設計は使えない。

正式に SSR まで対応するなら、generic virtual method ではなく、非 generic な renderer adapter を用意して type erase する必要がある。

### Dynamic dispatch / existential / heap allocation に注意が必要

`AnyView` は本質的に type erasure なので、box、closure、existential、dynamic dispatch のいずれかを使いやすい。Embedded Swift ではこの領域が壊れやすく、通常 Swift より慎重な設計が必要。

## 正式対応に必要そうな ElementaryUI 側の基盤

正式な `AnyView` を ElementaryUI に入れるなら、少なくとも次が必要。

1. DOM mount/patch 用の erased child mount API
2. HTML text rendering / async rendering 用の non-generic renderer adapter
3. Embedded Swift で使える stable view identity
4. `@View` macro による compile-time view type identity の生成
5. built-in views / structure views の identity 付与
6. `AnyView` の DOM / HTML / Embedded build テスト

特に identity は重要。同じ view type なら state を保って patch し、違う view type なら remount するために必要になる。

runtime reflection に頼らず、`@View` macro や built-in view 定義で compile-time に `_viewTypeID` のような値を生成する方向が現実的。

## Router 側の選択肢

`RouterView` をどう扱うかにはいくつか選択肢がある。

### 1. ElementaryUI に正式な AnyView を入れる

最も自然な解決策。ただし ElementaryUI 側の rendering model にしっかり手を入れる必要がある。

### 2. RouterView の本実装を保留する

安全な選択。route tree、matching、params、history、Link、not-found/error policy などは進められる。

ただし、実際に selected route view を描画する部分は ElementaryUI の type erasure が整うまで placeholder になる。

### 3. 全 route に同じ concrete view type を返させる

ElementaryUI の変更は少なくできるが、router API として不自然。

例えば全 route が enum wrapper view を返すような設計になる。ユーザー側に router 内部都合が漏れやすい。

### 4. ユーザーの body に switch を書かせる

ElementaryUI 側の変更は不要。ただし not-found、error、param decode fallback などを page body に押し戻すことになり、router の設計方針と逆。

### 5. route ごとに nested Application を mount する

公開 API だけで実験はしやすいが、environment/state/lifecycle が普通の view composition とずれるため、ライブラリ設計としては避けたい。

## 現時点の判断

Embedded Swift まで含めて ElementaryUI の機能をフルサポートする `AnyView` は、単純な小変更では済まない。

今回の vendor spike は「RouterView に必要な heterogeneous mount path が成立するか」を確認するには有効だった。一方で、ElementaryUI に正式に入れるなら HTML rendering、Embedded-safe identity、テストまで含めた設計が必要。

そのため ElementaryRouter の本線は、runtime `AnyView` ではなく `@Routes` macro が生成する typed route view union に切り替える。ユーザーは route ごとの page view を普通に書き、macro が `AppRoutes.RouteView` のような単一 concrete view type を生成する。

この方式なら `RouterView` は `RouteContent: View` を返すだけでよく、ElementaryUI に大きな type erasure API を要求せずに upstream ElementaryUI のまま進められる。vendor の `AnyView` spike は最終実装に残さない。

実装ではこの方針に移行した。`@Routes` が `RouteView` / `RouteSet` / route handles / href helpers を生成し、`@Layout` は `Outlet<Content>` を受け取る generic layout function として扱う。これにより nested layout も runtime erase せず、leaf view を layout function で静的に包める。

中長期的に ElementaryUI 側で `AnyView` または同等の type-erased child view abstraction を正式に設計する価値は残る。ただし router の初期 API は、それに依存しない typed macro 方式を優先する。

import ElementaryRouter
import ElementaryUI

@View
public struct BlogIndexPage<Root: View> {
  // The host's `Provider` installs this feature's route set for the host's root view type.
  @Environment(BlogRoutes<Root>.RouteSet.self) var blog: BlogRoutes<Root>.RouteSet?

  public var body: some View {
    article(.id("page"), .data("page", value: "blog-index")) {
      h2 { "Blog" }
      if let blog {
        ul {
          ForEach(BlogPost.all, key: { $0.slug }) { post in
            li(.id("link-post-\(post.slug)")) {
              BlogPostLink(blog: blog, slug: post.slug, title: post.title)
            }
          }
        }
      }
    }
  }
}

@View
public struct BlogPostPage<Root: View> {
  @Environment(BlogRoutes<Root>.RouteSet.self) var blog: BlogRoutes<Root>.RouteSet?

  let slug: String

  public var body: some View {
    article(.id("page"), .data("page", value: "blog-post"), .data("slug", value: slug)) {
      h2 { BlogPost.named(slug)?.title ?? "Unknown post" }
      p { "Posts link to each other through the blog's own typed destinations." }
      if let blog {
        // A feature-internal link: a static route, so its factory cannot fail.
        span(.id("link-blog-index")) {
          RouteLink(to: blog.posts()) { "All posts" }
        }
      }
    }
  }
}

/// A link to one post; post destinations have a path value, so they can fail to build.
@View
struct BlogPostLink<Root: View> {
  let blog: BlogRoutes<Root>.RouteSet
  let slug: String
  let title: String

  var body: some View {
    switch destination {
    case .success(let post):
      RouteLink(to: post) { title }
    case .failure:
      span { title }
    }
  }

  private var destination: Result<RouteDestination<Root>, RouteMatchError> {
    Result { () throws(RouteMatchError) in try blog.post(slug: slug) }
  }
}

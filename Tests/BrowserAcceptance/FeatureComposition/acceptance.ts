// Drives the mounted host through real DOM clicks and history traversal. It checks that host,
// feature-internal, and cross-feature links share one router and produce the host mode's hrefs,
// and which host and feature layout elements survive each navigation.
//
// `?mode=hash` runs the same scenario against the hash-mode host. The result is written to
// `#acceptance-result` (`data-status="pass"` or `"fail"`), to `document.title` (`PASS` or
// `FAIL: ...`), and to the console.

type Step = { name: string; run: () => Promise<void> };

const timeoutMs = 5000;
const hashMode = new URLSearchParams(location.search).get("mode") === "hash";

function query<T extends Element = HTMLElement>(selector: string): T | null {
  return document.querySelector<T>(selector) as T | null;
}

function required<T extends Element = HTMLElement>(selector: string): T {
  const element = query<T>(selector);
  if (!element) throw new Error(`missing ${selector}`);
  return element;
}

function nextFrame(): Promise<void> {
  return new Promise((resolve) => requestAnimationFrame(() => resolve()));
}

async function waitFor(description: string, predicate: () => boolean): Promise<void> {
  const deadline = performance.now() + timeoutMs;
  while (!predicate()) {
    if (performance.now() > deadline) throw new Error(`timed out waiting for ${description}`);
    await nextFrame();
  }
  await nextFrame();
  await nextFrame();
}

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function currentPage(): string | null {
  return query("#page")?.getAttribute("data-page") ?? null;
}

/// The route path of the current location: the document path, or the path inside the fragment.
function routePath(): string {
  const route = hashMode ? location.hash.slice(1) || "/" : location.pathname;
  return route.split("?")[0].split("#")[0];
}

/// The href a link to `route` must have in the active mode.
function expectedHref(route: string): string {
  return hashMode ? `#${route}` : route;
}

async function clickLink(id: string, route: string, page: string): Promise<void> {
  const anchor = required<HTMLAnchorElement>(`#${id} a`);
  expect(
    anchor.getAttribute("data-router-link") === "true",
    `#${id} is not a client-navigation link`,
  );
  const href = anchor.getAttribute("href");
  expect(
    href === expectedHref(route),
    `#${id} has href ${JSON.stringify(href)}, expected ${JSON.stringify(expectedHref(route))}`,
  );
  anchor.click();
  const path = route.split("?")[0];
  await waitFor(`${page} at ${path}`, () => currentPage() === page && routePath() === path);
}

/// Checks that the client-navigation link inside `#id` points at `route` in the active mode.
function expectHref(id: string, route: string): void {
  const anchor = required<HTMLAnchorElement>(`#${id} a`);
  expect(
    anchor.getAttribute("data-router-link") === "true",
    `#${id} is not a client-navigation link`,
  );
  const href = anchor.getAttribute("href");
  expect(
    href === expectedHref(route),
    `#${id} has href ${JSON.stringify(href)}, expected ${JSON.stringify(expectedHref(route))}`,
  );
}

async function type(selector: string, value: string): Promise<void> {
  const input = required<HTMLInputElement>(selector);
  input.value = value;
  input.dispatchEvent(new Event("input", { bubbles: true }));
  const echo = selector.replace("-draft", "-echo");
  await waitFor(`${echo} to show ${value}`, () => query(echo)?.textContent === value);
}

function expectText(selector: string, value: string): void {
  const text = query(selector)?.textContent ?? null;
  expect(text === value, `${selector} is ${JSON.stringify(text)}, expected ${JSON.stringify(value)}`);
}

export async function runFeatureCompositionAcceptance(): Promise<boolean> {
  const output = document.createElement("pre");
  output.id = "acceptance-result";
  output.setAttribute("data-status", "running");

  let shellInput: HTMLInputElement | null = null;
  let shopLayout: HTMLElement | null = null;
  let shopInput: HTMLInputElement | null = null;

  const steps: Step[] = [
    {
      name: `start at the host home page in ${hashMode ? "hash" : "path"} mode`,
      run: async () => {
        await waitFor("the host shell", () => query("#acceptance-shell") !== null);
        await waitFor("the home page", () => currentPage() === "home" && routePath() === "/");
        shellInput = required<HTMLInputElement>("#shell-draft");
        await type("#shell-draft", "shell-text");
        expect(
          required("#link-shop").getAttribute("data-active") === "false",
          "the shop link is active outside the shop",
        );
      },
    },
    {
      name: "the host named Routes keeps its own route set beside same-named features",
      run: async () => {
        // Only the path host is named `Routes` and has this home page. It reads the host route
        // set by the host's key and the alpha feature's route set by its type.
        if (hashMode) return;
        expectHref("host-link-alpha", "/alpha/items");
        expectHref("host-link-beta", "/beta/items");
        expectHref("feature-link-alpha", "/alpha");
      },
    },
    {
      name: "a host shell link enters the mounted shop",
      run: async () => {
        await clickLink("link-shop", "/shop", "shop-catalog");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
        expect(
          required("#link-shop").getAttribute("data-active") === "true",
          "the shop link is not active inside the shop",
        );
        shopLayout = required("#shop-layout");
        shopInput = required<HTMLInputElement>("#shop-draft");
        await type("#shop-draft", "shop-text");
      },
    },
    {
      name: "a feature-internal link keeps the shop layout and its state",
      run: async () => {
        await clickLink("link-product-1", "/shop/products/1", "shop-product");
        expect(query("#shop-layout") === shopLayout, "the shop layout element was replaced");
        expect(query("#shop-draft") === shopInput, "the shop input element was replaced");
        expectText("#shop-echo", "shop-text");
        expect(query("#shop-viewing-product") !== null, "the shop layout missed the product route");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
      },
    },
    {
      name: "a feature-internal link with a query stays in the shop",
      run: async () => {
        await clickLink("link-back", "/shop?sort=price", "shop-catalog");
        expect(query("#shop-layout") === shopLayout, "the shop layout element was replaced");
        expectText("#shop-echo", "shop-text");
        await clickLink("link-product-2", "/shop/products/2", "shop-product");
      },
    },
    {
      name: "a cross-feature link leaves the shop for the blog",
      run: async () => {
        await clickLink("link-review", "/blog/mug-review", "blog-post");
        expect(query("#shop-layout") === null, "the shop layout is still mounted");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
        expect(
          required("#link-shop").getAttribute("data-active") === "false",
          "the shop link is active in the blog",
        );
      },
    },
    {
      name: "a blog-internal link stays in the blog",
      run: async () => {
        await clickLink("link-blog-index", "/blog", "blog-index");
        await clickLink("link-post-teapot-review", "/blog/teapot-review", "blog-post");
      },
    },
    {
      name: "browser back re-enters the shop with a recreated shop layout",
      run: async () => {
        history.back();
        await waitFor("the blog index after back", () => currentPage() === "blog-index");
        history.back();
        await waitFor("the mug review after back", () => routePath() === "/blog/mug-review");
        history.back();
        await waitFor(
          "the product after back",
          () => currentPage() === "shop-product" && routePath() === "/shop/products/2",
        );
        const recreated = required("#shop-layout");
        expect(recreated !== shopLayout, "the shop layout element was not recreated");
        expectText("#shop-echo", "");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
      },
    },
    {
      name: "features named Routes from two modules each read their own route set",
      run: async () => {
        expectHref("link-alpha", "/alpha");
        expectHref("link-beta", "/beta");
        await clickLink("link-alpha", "/alpha", "guide-alpha");
        expectHref("guide-self", "/alpha");
        expectHref("guide-items", "/alpha/items");
        await clickLink("guide-items", "/alpha/items", "guide-alpha-items");
        await clickLink("link-beta", "/beta", "guide-beta");
        expectHref("guide-self", "/beta");
        expectHref("guide-items", "/beta/items");
        await clickLink("guide-items", "/beta/items", "guide-beta-items");
        expect(query("#guide-missing") === null, "a guide page found no route set");
      },
    },
  ];

  const log: string[] = [];
  let failure: string | null = null;
  for (const step of steps) {
    try {
      await step.run();
      log.push(`ok: ${step.name}`);
    } catch (error) {
      failure = `${step.name}: ${error instanceof Error ? error.message : String(error)}`;
      log.push(`FAIL: ${failure}`);
      break;
    }
  }

  const passed = failure === null;
  output.setAttribute("data-status", passed ? "pass" : "fail");
  output.textContent = [passed ? "PASS" : "FAIL", ...log].join("\n");
  document.body.appendChild(output);
  document.title = passed ? "PASS" : `FAIL: ${failure}`;
  console.log(output.textContent);
  return passed;
}

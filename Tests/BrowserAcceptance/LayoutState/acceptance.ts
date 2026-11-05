// Drives the mounted app through real DOM clicks and history traversal, and checks which
// layout elements and layout-owned `@State` values survive each navigation.
//
// The result is written to `#acceptance-result` (`data-status="pass"` or `"fail"`), to
// `document.title` (`PASS` or `FAIL: ...`), and to the console.

type Step = { name: string; run: () => Promise<void> };

const timeoutMs = 5000;

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
  // Let any pending reactive update settle before the next assertion.
  await nextFrame();
  await nextFrame();
}

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function currentPage(): string | null {
  return query("#page")?.getAttribute("data-page") ?? null;
}

async function clickLink(id: string, page: string, path: string): Promise<void> {
  const anchor = required<HTMLAnchorElement>(`#${id} a`);
  expect(
    anchor.getAttribute("data-router-link") === "true",
    `#${id} is not a client-navigation link`,
  );
  anchor.click();
  await waitFor(`${page} at ${path}`, () => currentPage() === page && location.pathname === path);
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

export async function runLayoutStateAcceptance(): Promise<boolean> {
  const output = document.createElement("pre");
  output.id = "acceptance-result";
  output.setAttribute("data-status", "running");

  let shellInput: HTMLInputElement | null = null;
  let teamInput: HTMLInputElement | null = null;
  let teamSection: HTMLElement | null = null;

  const steps: Step[] = [
    {
      name: "start at home with an empty shell draft",
      run: async () => {
        await waitFor("the shell layout", () => query("#shell-layout") !== null);
        await clickLink("link-home", "home", "/");
        shellInput = required<HTMLInputElement>("#shell-draft");
        await type("#shell-draft", "shell-text");
      },
    },
    {
      name: "entering the team branch keeps the shell layout mounted",
      run: async () => {
        await clickLink("link-team-index", "team-index", "/teams/7");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
        teamInput = required<HTMLInputElement>("#team-draft");
        teamSection = required("#team-layout");
        await type("#team-draft", "team-text");
        required<HTMLButtonElement>("#team-count").click();
        await waitFor("the team counter", () => query("#team-count")?.textContent === "Count 1");
      },
    },
    {
      name: "a sibling child route keeps the team layout and its state",
      run: async () => {
        const page = required("#page");
        await clickLink("link-member", "member", "/teams/7/members/42");
        expect(query("#page") !== page, "the child page was not replaced");
        expect(query("#team-layout") === teamSection, "the team layout element was replaced");
        expect(query("#team-draft") === teamInput, "the team input element was replaced");
        expect(teamInput!.value === "team-text", "the team input lost its value");
        expectText("#team-echo", "team-text");
        expectText("#team-count", "Count 1");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
      },
    },
    {
      name: "returning to the index route keeps the team layout and its state",
      run: async () => {
        await clickLink("link-team-index", "team-index", "/teams/7");
        expect(query("#team-draft") === teamInput, "the team input element was replaced");
        expectText("#team-echo", "team-text");
        expectText("#team-count", "Count 1");
      },
    },
    {
      name: "rebuilding the parent of RouterView keeps the router and every layout",
      run: async () => {
        const before = Number(required("#parent-rebuilds").textContent);
        required<HTMLButtonElement>("#rebuild-parent").click();
        await waitFor(
          "the parent rebuild",
          () => Number(query("#parent-rebuilds")?.textContent) === before + 1,
        );
        expect(currentPage() === "team-index", "the rendered route changed");
        expect(query("#team-draft") === teamInput, "the team input element was replaced");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#team-echo", "team-text");
        // Links still navigate with the router the view kept.
        await clickLink("link-member", "member", "/teams/7/members/42");
        expect(query("#team-draft") === teamInput, "the team input element was replaced");
        await clickLink("link-team-index", "team-index", "/teams/7");
      },
    },
    {
      name: "another team id stays in the team branch and updates the layout values",
      run: async () => {
        await clickLink("link-other-team", "team-index", "/teams/8");
        expect(query("#team-layout") === teamSection, "the team layout element was replaced");
        expect(
          teamSection!.getAttribute("data-team-id") === "8",
          "the team layout did not receive its new teamID",
        );
        expectText("#team-echo", "team-text");
        await clickLink("link-team-index", "team-index", "/teams/7");
      },
    },
    {
      name: "leaving the team branch unmounts the team layout",
      run: async () => {
        await clickLink("link-settings", "settings", "/settings");
        expect(query("#team-layout") === null, "the team layout is still mounted");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
      },
    },
    {
      name: "browser back re-enters the team branch with a recreated layout",
      run: async () => {
        history.back();
        await waitFor("team-index after back", () => currentPage() === "team-index");
        const recreated = required<HTMLInputElement>("#team-draft");
        expect(recreated !== teamInput, "the team input element was not recreated");
        expect(recreated.value === "", "the recreated team input kept the old value");
        expectText("#team-echo", "");
        expectText("#team-count", "Count 0");
        expect(query("#shell-draft") === shellInput, "the shell input element was replaced");
        expectText("#shell-echo", "shell-text");
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

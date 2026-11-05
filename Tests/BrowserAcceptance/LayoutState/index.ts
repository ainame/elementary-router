import { runApplication } from "elementary-ui-browser-runtime";
import appInit from "virtual:swift-wasm?init";
import { runLayoutStateAcceptance } from "./acceptance";

declare global {
  interface Window {
    runLayoutStateAcceptance: typeof runLayoutStateAcceptance;
  }
}

window.runLayoutStateAcceptance = runLayoutStateAcceptance;

// Read the flag before the app or the scenario changes the URL.
const runsAcceptance = new URLSearchParams(location.search).has("acceptance");

await runApplication(appInit);

if (runsAcceptance) {
  await runLayoutStateAcceptance();
}

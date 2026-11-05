import { runApplication } from "elementary-ui-browser-runtime";
import appInit from "virtual:swift-wasm?init";
import { runFeatureCompositionAcceptance } from "./acceptance";

declare global {
  interface Window {
    runFeatureCompositionAcceptance: typeof runFeatureCompositionAcceptance;
  }
}

window.runFeatureCompositionAcceptance = runFeatureCompositionAcceptance;

// Read the flag before the app or the scenario changes the URL.
const runsAcceptance = new URLSearchParams(location.search).has("acceptance");

await runApplication(appInit);

if (runsAcceptance) {
  await runFeatureCompositionAcceptance();
}

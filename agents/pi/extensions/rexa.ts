import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";

const REXA_ADAPTER = "/Applications/Rexa.app/Contents/Resources/extensions/pi-adapter/pi-extensions/rexa.ts";

export default async function rexaExtension(pi: ExtensionAPI) {
  if (!existsSync(REXA_ADAPTER)) return;
  const adapter = await import(REXA_ADAPTER);
  await adapter.default(pi);
}

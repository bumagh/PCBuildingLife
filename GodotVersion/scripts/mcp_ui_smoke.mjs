import path from "node:path";
import { Client } from "file:///C:/Users/admin/.codex/vendor_imports/godot-mcp/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js";
import { StdioClientTransport } from "file:///C:/Users/admin/.codex/vendor_imports/godot-mcp/server/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js";
import { spawn } from "node:child_process";

const SERVER = "C:\\Users\\admin\\.codex\\vendor_imports\\godot-mcp\\server\\build\\index.js";
const GODOT = "D:\\1exe\\3Dev\\1GameEngine\\Godot_v4.7-rc3_win64\\Godot_v4.7-rc3_win64.exe";
const MCP_PORT = "6516";
const PROJECT_DIR = path.resolve("GodotVersion");
const PROJECT_SCENE = "res://scenes/Game.tscn";

let editor = null;

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [SERVER],
  env: { ...process.env, GODOT_MCP_PORT: MCP_PORT },
});

const client = new Client(
  { name: "pcbuildinglife-mcp-smoke", version: "1.0.0" },
  { capabilities: {} }
);

async function callTool(name, args = {}) {
  const result = await client.callTool({ name, arguments: args });
  const text = result.content?.[0]?.text ?? "{}";
  const parsed = JSON.parse(text);
  if (parsed.error) return parsed;
  return parsed.result ?? parsed;
}

async function waitForGodot() {
  for (let i = 0; i < 60; i += 1) {
    const result = await callTool("get_project_info");
    if (!result.error) return result;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error("Temporary Godot editor did not connect to MCP.");
}

async function waitForUiText(minCount = 20) {
  for (let i = 0; i < 30; i += 1) {
    const ui = normalizeUi(await callTool("find_ui_elements"));
    const texts = ui.map((item) => String(item.text)).filter(Boolean);
    if (texts.length >= minCount) return { ui, texts };
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  const ui = normalizeUi(await callTool("find_ui_elements"));
  return { ui, texts: ui.map((item) => String(item.text)).filter(Boolean) };
}

async function waitForUiTextMatch(predicate, description, minCount = 1) {
  let lastTexts = [];
  for (let i = 0; i < 30; i += 1) {
    const ui = normalizeUi(await callTool("find_ui_elements"));
    const texts = ui.map((item) => String(item.text)).filter(Boolean);
    lastTexts = texts;
    if (texts.length >= minCount && texts.some(predicate)) return { ui, texts };
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Expected MCP to see ${description}. Last UI texts: ${lastTexts.slice(0, 40).join(" | ")}`);
}

function normalizeUi(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.result)) return value.result;
  if (Array.isArray(value?.elements)) return value.elements;
  return [];
}

function assertToolResult(value, description) {
  if (value && typeof value === "object" && value.error) {
    throw new Error(`Expected ${description}, got: ${JSON.stringify(value)}`);
  }
  return value;
}

async function clickText(text) {
  const result = assertToolResult(
    await callTool("click_button_by_text", { text }),
    `MCP click button "${text}"`
  );
  await new Promise((resolve) => setTimeout(resolve, 350));
  return result;
}

async function clickAt(x, y) {
  assertToolResult(
    await callTool("simulate_mouse_click", { x, y, button: 1 }),
    `MCP click at ${x},${y}`
  );
  await new Promise((resolve) => setTimeout(resolve, 350));
}

async function clickTextOrAt(text, x, y) {
  const result = await callTool("click_button_by_text", { text });
  if (result && typeof result === "object" && result.error) {
    await clickAt(x, y);
    return;
  }
  await new Promise((resolve) => setTimeout(resolve, 350));
}

async function waitForScreenshot() {
  let last = null;
  for (let i = 0; i < 8; i += 1) {
    last = await callTool("get_game_screenshot");
    if (!last?.error) return last;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return last;
}

async function main() {
  await client.connect(transport);

  editor = spawn(GODOT, ["--path", PROJECT_DIR, "--editor"], {
    env: { ...process.env, GODOT_MCP_PORT: MCP_PORT },
    stdio: ["ignore", "ignore", "pipe"],
  });
  editor.stderr.on("data", (chunk) => process.stderr.write(chunk));

  await waitForGodot();
  await callTool("open_scene", { scene_path: PROJECT_SCENE });
  await callTool("play_scene", { mode: "custom", scene_path: PROJECT_SCENE });
  await new Promise((resolve) => setTimeout(resolve, 1600));

  let { ui, texts } = await waitForUiText();
  if (texts.length < 20) {
    throw new Error(`Expected populated UI via MCP, got ${texts.length} text nodes.`);
  }
  if (!texts.some((text) => text.includes("新手引导")) || !texts.some((text) => text.includes("查看订单"))) {
    throw new Error("Expected MCP to see the actionable onboarding guide.");
  }
	ui = await callTool("find_ui_elements");
	const statusText = ui.map((item) => String(item.text)).find((text) => text.includes("璁㈠崟") || text.includes("订单")) ?? "";

  const screenshot = await waitForScreenshot();
  const screenshotStatus = screenshot.error ? `screenshot_warning=${screenshot.error}` : "screenshot=ok";
  await callTool("stop_scene");

  console.log("mcp_ui_smoke=ok");
  console.log(`ui_texts=${texts.length}`);
  console.log("onboarding_guide=visible");
  console.log(`status=${statusText}`);
  console.log(screenshotStatus);
}

main()
  .catch(async (error) => {
    console.error(error);
    try {
      await callTool("stop_scene");
    } catch {
      // ignore cleanup failures
    }
    process.exitCode = 1;
  })
  .finally(async () => {
    if (editor) editor.kill();
    await client.close();
  });

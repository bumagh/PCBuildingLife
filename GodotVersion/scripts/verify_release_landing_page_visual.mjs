import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");
const defaultBundle = path.join(repoRoot, "GodotVersion", "build", "upload", "PCBuildingLife-0.1.0-dev");

const args = process.argv.slice(2);
let bundleDir = defaultBundle;
let browserPath = "";

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--browser") {
    browserPath = path.resolve(args[i + 1] || "");
    i += 1;
  } else if (arg === "--bundle") {
    bundleDir = path.resolve(args[i + 1] || "");
    i += 1;
  } else if (!arg.startsWith("--")) {
    bundleDir = path.resolve(arg);
  }
}

const htmlPath = path.join(bundleDir, "index.html");
const outputDir = path.join(bundleDir, "visual-checks");
const shots = [
  { name: "desktop", width: 1280, height: 720 },
  { name: "mobile", width: 390, height: 844 },
];

function fail(message) {
  console.error(`[landing-visual] ${message}`);
  process.exit(1);
}

function mustExist(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing file: ${filePath}`);
  }
}

function candidateBrowsers() {
  const candidates = [];
  if (browserPath) {
    candidates.push(browserPath);
  }

  if (process.platform === "win32") {
    const roots = [
      process.env.PROGRAMFILES,
      process.env["PROGRAMFILES(X86)"],
      process.env.LOCALAPPDATA,
    ].filter(Boolean);

    for (const root of roots) {
      candidates.push(path.join(root, "Microsoft", "Edge", "Application", "msedge.exe"));
      candidates.push(path.join(root, "Google", "Chrome", "Application", "chrome.exe"));
    }
  } else if (process.platform === "darwin") {
    candidates.push("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome");
    candidates.push("/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge");
    candidates.push("/Applications/Chromium.app/Contents/MacOS/Chromium");
  } else {
    candidates.push("google-chrome");
    candidates.push("google-chrome-stable");
    candidates.push("microsoft-edge");
    candidates.push("chromium");
    candidates.push("chromium-browser");
  }

  return [...new Set(candidates)].filter(Boolean);
}

function findBrowser() {
  for (const candidate of candidateBrowsers()) {
    if (path.isAbsolute(candidate) && !fs.existsSync(candidate)) {
      continue;
    }

    const version = spawnSync(candidate, ["--version"], {
      encoding: "utf8",
      windowsHide: true,
      timeout: 8000,
    });

    if (version.status === 0 || fs.existsSync(candidate)) {
      return candidate;
    }
  }

  fail("No Edge, Chrome, or Chromium executable was found. Pass --browser <path> to override.");
}

function readPngSize(filePath) {
  const buffer = fs.readFileSync(filePath);
  const signature = buffer.subarray(0, 8).toString("hex");
  if (signature !== "89504e470d0a1a0a") {
    fail(`Screenshot is not a PNG: ${filePath}`);
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    bytes: buffer.length,
  };
}

mustExist(htmlPath);
fs.mkdirSync(outputDir, { recursive: true });

const browser = findBrowser();
const htmlUrl = pathToFileURL(htmlPath).href;
const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), "pcbuildinglife-landing-"));

try {
  for (const shot of shots) {
    const outPath = path.join(outputDir, `landing-page-${shot.name}-${shot.width}x${shot.height}.png`);
    if (fs.existsSync(outPath)) {
      fs.unlinkSync(outPath);
    }

    const result = spawnSync(browser, [
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      `--user-data-dir=${userDataDir}`,
      `--window-size=${shot.width},${shot.height}`,
      `--screenshot=${outPath}`,
      htmlUrl,
    ], {
      encoding: "utf8",
      windowsHide: true,
      timeout: 30000,
    });

    if (result.error) {
      fail(`Browser screenshot failed: ${result.error.message}`);
    }
    if (result.status !== 0) {
      fail(`Browser exited with ${result.status}: ${(result.stderr || result.stdout || "").trim()}`);
    }

    mustExist(outPath);
    const png = readPngSize(outPath);
    if (png.width !== shot.width || png.height !== shot.height) {
      fail(`Screenshot size mismatch for ${shot.name}: ${png.width}x${png.height} != ${shot.width}x${shot.height}`);
    }
    if (png.bytes < 20000) {
      fail(`Screenshot looks too small to be a real page capture: ${outPath} (${png.bytes} bytes)`);
    }

    console.log(`[landing-visual] ${shot.name}=${outPath}`);
  }
} finally {
  fs.rmSync(userDataDir, { recursive: true, force: true });
}

console.log(`[landing-visual] browser=${browser}`);
console.log("[landing-visual] ok");

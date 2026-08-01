import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");
const defaultBundle = path.join(repoRoot, "GodotVersion", "build", "upload", "PCBuildingLife-0.1.0-dev");
const bundleDir = path.resolve(process.argv[2] || defaultBundle);
const htmlPath = path.join(bundleDir, "index.html");
const manifestPath = path.join(bundleDir, "upload-manifest.json");

function fail(message) {
  console.error(`[landing-page] ${message}`);
  process.exit(1);
}

function mustExist(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing file: ${filePath}`);
  }
}

mustExist(htmlPath);
mustExist(manifestPath);

const html = fs.readFileSync(htmlPath, "utf8");
const manifestText = fs.readFileSync(manifestPath, "utf8").replace(/^\uFEFF/, "");
const manifest = JSON.parse(manifestText);
const formattedPackageSize = `${new Intl.NumberFormat("en-US").format(manifest.package_size_bytes)} bytes`;

for (const text of [
  "装机人生",
  "PC Building Life",
  manifest.package_sha256,
  manifest.exe_sha256,
  manifest.feedback_url,
  manifest.package_zip,
  manifest.package_sha256_file,
  formattedPackageSize,
]) {
  if (!html.includes(text)) {
    fail(`HTML does not contain expected text: ${text}`);
  }
}

const refs = [];
for (const match of html.matchAll(/\b(?:src|href)="([^"]+)"/g)) {
  const ref = match[1];
  if (/^(https?:|mailto:|#)/i.test(ref)) {
    continue;
  }
  refs.push(ref);
}

if (refs.length < 8) {
  fail(`Expected multiple local refs, found ${refs.length}.`);
}

for (const ref of refs) {
  const cleanRef = ref.split("#")[0].split("?")[0];
  const target = path.resolve(bundleDir, cleanRef);
  if (!target.startsWith(bundleDir)) {
    fail(`Ref escapes bundle directory: ${ref}`);
  }
  mustExist(target);
}

const zipPath = path.join(bundleDir, manifest.package_zip);
const shaPath = path.join(bundleDir, manifest.package_sha256_file);
mustExist(zipPath);
mustExist(shaPath);

const zipBytes = fs.statSync(zipPath).size;
if (zipBytes !== manifest.package_size_bytes) {
  fail(`ZIP size mismatch: ${zipBytes} != ${manifest.package_size_bytes}`);
}

const shaText = fs.readFileSync(shaPath, "ascii");
if (!shaText.includes(manifest.package_sha256)) {
  fail("SHA-256 file does not include manifest package hash.");
}

console.log("[landing-page] ok");
console.log(`[landing-page] refs=${refs.length}`);
console.log(`[landing-page] ${htmlPath}`);

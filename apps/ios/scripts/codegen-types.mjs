#!/usr/bin/env node
/**
 * Generates Swift model types from the TypeScript types in `packages/core/types`.
 *
 * Why: the canonical source of truth for Multica's data model lives in
 *      `packages/core/types/*.ts`. The Swift app must stay byte-compatible
 *      with what the Go server sends and what the web/desktop apps decode.
 *
 * What: parses a curated allow-list of TS interfaces (the ones the iOS app
 *       actually wire-decodes) and emits a single Swift file with
 *       `Codable, Identifiable, Hashable, Sendable` structs using the
 *       webapp's snake_case API contract via `CodingKeys`.
 *
 * How: lightweight TS-to-Swift transform. We don't run the TS compiler —
 *      we parse `interface X { … }` declarations directly. This keeps the
 *      script dependency-free and fast (no `tsc`, no `quicktype`).
 *
 * Output: apps/ios/Multica/Models/Generated.swift
 *
 * IMPORTANT: hand-written types in `Models/Models.swift` take precedence
 *            until we delete them. Generated types live in the `Generated`
 *            namespace to avoid collisions; switch consumers over one type
 *            at a time, then remove the hand-written version.
 */

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, "../../..");
const TYPES_DIR = join(REPO_ROOT, "packages/core/types");
const OUT_PATH = join(__dirname, "../Multica/Models/Generated.swift");

// Curated list — only generate types the iOS app actually decodes from
// the wire. Other types in packages/core/types are web-only (e.g. timeline
// activity entries, label colors).
const SOURCES = [
  { file: "workspace.ts", types: ["User", "Workspace"] },
  { file: "issue.ts", types: ["Issue"] },
  { file: "label.ts", types: ["Label"] },
  { file: "comment.ts", types: ["Comment"] },
  { file: "inbox.ts", types: ["InboxItem"] },
  { file: "agent.ts", types: ["Agent"] },
  { file: "project.ts", types: ["Project", "ProjectResource"] },
  { file: "squad.ts", types: ["Squad", "SquadMember"] },
  { file: "autopilot.ts", types: ["Autopilot", "AutopilotTrigger", "AutopilotRun"] },
];

function snakeToCamel(s) {
  return s.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

function tsTypeToSwift(tsType, fieldName, knownTypes) {
  const t = tsType.trim();

  // unions of string literals → String
  if (/^"[^"]+"(\s*\|\s*"[^"]+")+$/.test(t)) return "String";
  // unions with `null` → optional of the non-null variant
  if (/\| ?null/.test(t)) {
    const without = t.replace(/\| ?null/g, "").trim();
    return tsTypeToSwift(without, fieldName, knownTypes) + "?";
  }

  if (t === "string") return "String";
  if (t === "number") return "Double";
  if (t === "boolean") return "Bool";
  if (t === "unknown" || t === "any") return "AnyCodable";

  // arrays
  const arr = t.match(/^(.+)\[\]$/) || t.match(/^Array<(.+)>$/);
  if (arr) return `[${tsTypeToSwift(arr[1], fieldName, knownTypes)}]`;

  // bare identifier — only emit if generated this run, else opaque
  if (/^[A-Z][A-Za-z0-9_]*$/.test(t)) {
    if (knownTypes.has(t)) return t;
    return "AnyCodable";
  }

  return "AnyCodable";
}

// Parse a single `export interface Name { … }` block.
function parseInterface(source, name, knownTypes) {
  const re = new RegExp(`export interface ${name} \\{([\\s\\S]*?)\\n\\}`, "m");
  const m = source.match(re);
  if (!m) return null;
  const body = m[1];
  const fields = [];
  for (const line of body.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("//") || trimmed.startsWith("/*")) continue;
    const fm = trimmed.match(/^([a-zA-Z_][a-zA-Z0-9_]*)(\??):\s*(.+?);?$/);
    if (!fm) continue;
    const [, snake, opt, rawType] = fm;
    let swiftType = tsTypeToSwift(rawType, snake, knownTypes);
    if (opt === "?" && !swiftType.endsWith("?")) swiftType += "?";
    fields.push({ snake, camel: snakeToCamel(snake), swiftType });
  }
  return { name, fields };
}

function emitStruct({ name, fields }) {
  const lines = [];
  lines.push(`/// Mirrors \`${name}\` from packages/core/types.`);
  lines.push(`/// Generated — do not edit by hand. Run \`pnpm --filter @multica/ios codegen\`.`);
  lines.push(`struct ${name}: Codable, Identifiable, Hashable, Sendable {`);
  for (const f of fields) {
    lines.push(`    let ${f.camel}: ${f.swiftType}`);
  }
  // Identifiable conformance: requires `id`. Most Multica types have `id: string`.
  const hasId = fields.some((f) => f.camel === "id");
  if (!hasId) {
    // synthesize a unique id from a hash of all fields — only used by Identifiable
    lines.push(`    var id: String { String(describing: self).hashValue.description }`);
  }
  lines.push(`    enum CodingKeys: String, CodingKey {`);
  for (const f of fields) {
    if (f.snake === f.camel) {
      lines.push(`        case ${f.camel}`);
    } else {
      lines.push(`        case ${f.camel} = "${f.snake}"`);
    }
  }
  lines.push(`    }`);
  lines.push(`}`);
  return lines.join("\n");
}

async function main() {
  if (!existsSync(TYPES_DIR)) {
    console.error(`✗ Types dir not found at ${TYPES_DIR}`);
    process.exit(1);
  }
  const blocks = [];
  const knownTypes = new Set(SOURCES.flatMap((s) => s.types));
  for (const src of SOURCES) {
    const file = join(TYPES_DIR, src.file);
    if (!existsSync(file)) {
      console.warn(`⚠ skip: ${src.file} not found`);
      continue;
    }
    const source = await readFile(file, "utf8");
    for (const type of src.types) {
      const parsed = parseInterface(source, type, knownTypes);
      if (!parsed) {
        console.warn(`⚠ skip: ${type} not found in ${src.file}`);
        continue;
      }
      blocks.push(emitStruct(parsed));
    }
  }
  const header =
    `// Generated from packages/core/types — do not edit by hand.\n` +
    `// Run \`pnpm --filter @multica/ios codegen\` to regenerate.\n\n` +
    `import Foundation\n\n` +
    `enum Generated {}\n\n` +
    `extension Generated {\n`;
  const footer = `\n}\n`;
  const body = blocks.map((b) => b.replace(/^/gm, "    ")).join("\n\n");

  await mkdir(dirname(OUT_PATH), { recursive: true });
  await writeFile(OUT_PATH, header + body + footer);
  console.log(`✓ wrote ${OUT_PATH} (${blocks.length} types from ${SOURCES.length} sources)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

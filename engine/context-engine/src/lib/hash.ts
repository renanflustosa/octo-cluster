import { createHash } from "node:crypto";

export function contentHash(text: string): string {
  return createHash("sha256").update(text).digest("hex").slice(0, 16);
}

export function fileKey(repo: string, relPath: string): string {
  return `${repo}:${relPath.replace(/\\/g, "/")}`;
}

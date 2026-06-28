import type { FeatureExtractionPipeline } from "@xenova/transformers";

let pipeline: FeatureExtractionPipeline | null = null;

export async function embedText(text: string): Promise<number[]> {
  if (!pipeline) {
    const { pipeline: createPipeline } = await import("@xenova/transformers");
    pipeline = (await createPipeline(
      "feature-extraction",
      "Xenova/all-MiniLM-L6-v2",
    )) as FeatureExtractionPipeline;
  }

  const output = await pipeline(text, { pooling: "mean", normalize: true });
  return Array.from(output.data as Float32Array);
}

export function keywordScore(query: string, text: string): number {
  const terms = query
    .toLowerCase()
    .split(/\W+/)
    .filter((t) => t.length > 2);
  if (terms.length === 0) return 0;

  const hay = text.toLowerCase();
  let hits = 0;
  for (const term of terms) {
    if (hay.includes(term)) hits += 1;
  }
  return hits / terms.length;
}

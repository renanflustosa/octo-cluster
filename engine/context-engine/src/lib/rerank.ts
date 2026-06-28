import {
  AutoModelForSequenceClassification,
  AutoTokenizer,
  type PreTrainedModel,
  type PreTrainedTokenizer,
} from "@xenova/transformers";

// Cross-encoder reranker (local, ONNX). Scores each (query, passage) pair for
// relevance. This is the precision stage: embedding topK -> rerank -> topN.
const MODEL_ID = "Xenova/ms-marco-MiniLM-L-6-v2";

let tokenizer: PreTrainedTokenizer | null = null;
let model: PreTrainedModel | null = null;

async function load() {
  if (!tokenizer || !model) {
    tokenizer = await AutoTokenizer.from_pretrained(MODEL_ID);
    model = await AutoModelForSequenceClassification.from_pretrained(MODEL_ID, {
      quantized: true,
    });
  }
  return { tokenizer, model };
}

export type Rerankable = { text: string };

/**
 * Reorders `docs` by cross-encoder relevance to `query` and returns the best
 * `topN`. If the model cannot load (e.g. offline first run), the input order is
 * preserved and the first `topN` are returned — retrieval never hard-fails.
 */
export async function rerank<T extends Rerankable>(
  query: string,
  docs: T[],
  topN: number,
): Promise<Array<T & { _rerank?: number }>> {
  if (docs.length === 0) return [];
  if (docs.length === 1) return docs.slice(0, topN);

  try {
    const { tokenizer: tok, model: mdl } = await load();
    const inputs = await tok(
      docs.map(() => query),
      {
        text_pair: docs.map((d) => d.text),
        padding: true,
        truncation: true,
      },
    );
    const { logits } = await mdl(inputs);
    const scores = Array.from(logits.data as Float32Array);

    return docs
      .map((d, i) => ({ ...d, _rerank: scores[i] ?? 0 }))
      .sort((a, b) => (b._rerank ?? 0) - (a._rerank ?? 0))
      .slice(0, topN);
  } catch {
    return docs.slice(0, topN);
  }
}

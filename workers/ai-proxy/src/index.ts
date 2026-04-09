// relateos-ai-proxy
// Cloudflare Worker edge proxy for RelateOS keyboard inference.

const GEMINI_MODEL = 'gemini-2.5-pro';
const RATE_LIMIT_PER_MIN = 60;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;

type ModelTier = 'local' | 'edge-realtime' | 'deep-context';

interface KeyboardMessage {
  role: 'user' | 'other';
  text: string;
  lang?: string;
}

interface AnalyzeIntentRequest {
  user_id?: string;
  target_language?: string;
  context_messages?: string[];
  current_draft?: string;

  // Keyboard extension payload format
  draft?: string;
  messages?: KeyboardMessage[];
  locale?: string;
  ts?: string;
}

interface SuggestionItem {
  tone: string;
  text: string;
  confidence?: number;
}

interface AnalyzeIntentResponse {
  subtext_explanation: string;
  suggestions: SuggestionItem[];
  health_delta: number;
  latency_ms: number;
  detected_emotion: string;
  model_tier: ModelTier;
}

interface Env {
  GEMINI_API_KEY: string;
  DEEPSEEK_API_KEY?: string;
  QWEN_API_KEY?: string;
  RATE_LIMIT_STORE: KVNamespace;
  CACHE_STORE?: KVNamespace;
  ENCRYPTION_KEY?: string;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Nonce',
    },
  });
}

function parseBearerToken(request: Request): string {
  const auth = request.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) {
    return '';
  }
  return auth.slice('Bearer '.length).trim();
}

function bytesToUtf8(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

function utf8ToBytes(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

function b64ToBytes(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4 || 4)) % 4);
  const raw = atob(padded);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    bytes[i] = raw.charCodeAt(i);
  }
  return bytes;
}

function asArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function sha256(data: Uint8Array): Promise<Uint8Array> {
  const hash = await crypto.subtle.digest('SHA-256', asArrayBuffer(data));
  return new Uint8Array(hash);
}

async function deriveAesKey(request: Request, env: Env): Promise<CryptoKey> {
  const bearer = parseBearerToken(request);
  if (bearer) {
    const digest = await sha256(utf8ToBytes(bearer));
    return crypto.subtle.importKey('raw', asArrayBuffer(digest), { name: 'AES-GCM' }, false, ['decrypt', 'encrypt']);
  }

  const fallback = env.ENCRYPTION_KEY || 'development_fallback_key_32bytes!!';
  let raw = utf8ToBytes(fallback);
  if (fallback.includes('=') || fallback.includes('-') || fallback.includes('_')) {
    try {
      raw = b64ToBytes(fallback);
    } catch {
      // keep UTF-8 fallback
    }
  }
  const digest = await sha256(raw);
  return crypto.subtle.importKey('raw', asArrayBuffer(digest), { name: 'AES-GCM' }, false, ['decrypt', 'encrypt']);
}

async function encryptedJSONResponse(body: unknown, request: Request, env: Env, status = 200): Promise<Response> {
  const key = await deriveAesKey(request, env);
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const plaintext = utf8ToBytes(JSON.stringify(body));

  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: nonce, tagLength: 128 },
    key,
    asArrayBuffer(plaintext)
  );

  const cipherAndTag = new Uint8Array(encrypted);
  const combined = concatBytes(nonce, cipherAndTag);

  return new Response(asArrayBuffer(combined), {
    status,
    headers: {
      'Content-Type': 'application/octet-stream',
      'X-Response-Nonce': bytesToHex(nonce),
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Nonce',
    },
  });
}

async function maybeDecryptRequest(request: Request, env: Env): Promise<AnalyzeIntentRequest> {
  const contentType = request.headers.get('Content-Type') || '';

  if (!contentType.includes('application/octet-stream')) {
    return (await request.json()) as AnalyzeIntentRequest;
  }

  const encrypted = new Uint8Array(await request.arrayBuffer());
  if (encrypted.length < 12 + 16) {
    throw new Error('Encrypted payload too small');
  }

  // CryptoKit combined format: nonce(12) + ciphertext + tag(16)
  const nonce = encrypted.slice(0, 12);
  const cipherAndTag = encrypted.slice(12);

  const key = await deriveAesKey(request, env);
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: nonce, tagLength: 128 },
    key,
    cipherAndTag
  );

  const plaintext = bytesToUtf8(new Uint8Array(decrypted));
  return JSON.parse(plaintext) as AnalyzeIntentRequest;
}

function normalizeRequest(input: AnalyzeIntentRequest): {
  userId: string;
  targetLanguage: string;
  draft: string;
  contextMessages: string[];
} {
  const draft = input.current_draft ?? input.draft ?? '';
  const contextFromArray = input.context_messages ?? [];
  const contextFromMessages = (input.messages ?? []).map((m) => m.text);
  const contextMessages = contextFromArray.length > 0 ? contextFromArray : contextFromMessages;

  return {
    userId: input.user_id ?? 'anonymous',
    targetLanguage: input.target_language ?? input.locale ?? 'auto',
    draft,
    contextMessages,
  };
}

async function enforceRateLimit(userId: string, env: Env): Promise<void> {
  const key = `rate_limit:${userId}`;
  const stored = await env.RATE_LIMIT_STORE.get(key);

  let count = 0;
  let ts = Date.now();

  if (stored) {
    const parsed = JSON.parse(stored) as { count: number; ts: number };
    if (Date.now() - parsed.ts < RATE_LIMIT_WINDOW_MS) {
      count = parsed.count;
      ts = parsed.ts;
    }
  }

  if (count >= RATE_LIMIT_PER_MIN) {
    throw new Error('Rate limit exceeded');
  }

  await env.RATE_LIMIT_STORE.put(
    key,
    JSON.stringify({ count: count + 1, ts }),
    { expirationTtl: 60 }
  );
}

function regexRedaction(text: string): string {
  let scrubbed = text;

  scrubbed = scrubbed.replace(/[A-Z]\d{6}\([A0-9]\)/gi, '<PII_HKID>');
  scrubbed = scrubbed.replace(/[^\s@]+@[^\s@]+\.[^\s@]+/gi, '<PII_EMAIL>');
  scrubbed = scrubbed.replace(/(\+852\s?|00852\s?)?[2-9]\d{7}/g, '<PII_PHONE>');
  scrubbed = scrubbed.replace(/\b(?:\d[ -]*?){13,19}\b/g, '<PII_CARD>');

  return scrubbed;
}

function contextualRedaction(text: string): string {
  const lexicon: Record<string, string> = {
    'causeway bay': '<PII_PLACE>',
    central: '<PII_PLACE>',
    admiralty: '<PII_PLACE>',
    kowloon: '<PII_PLACE>',
    'hong kong island': '<PII_PLACE>',
    'new territories': '<PII_PLACE>',
    mtr: '<PII_TRANSIT>',
  };

  let out = text;
  for (const [term, token] of Object.entries(lexicon)) {
    out = out.replace(new RegExp(term, 'gi'), token);
  }

  out = out.replace(/\b\d+\s+[A-Za-z][A-Za-z\s]{2,40}\s(Road|Street|Avenue|Lane|Drive|Court)\b/gi, '<PII_ADDRESS>');
  return out;
}

function recapRedact(text: string): string {
  const phase1 = regexRedaction(text);
  const phase2 = contextualRedaction(phase1);
  return phase2;
}

async function cacheKeyForRequest(
  tier: ModelTier,
  targetLanguage: string,
  draft: string,
  messages: string[]
): Promise<string> {
  const payload = `${tier}|${targetLanguage}|${draft}|${messages.join("\n")}`;
  const digest = await sha256(utf8ToBytes(payload));
  return `intent:${bytesToHex(digest).slice(0, 32)}`;
}

function selectModelTier(draft: string, messages: string[], targetLanguage: string): ModelTier {
  const joined = `${draft}\n${messages.join('\n')}`;
  const charCount = joined.length;
  const hasCjk = /[\u3400-\u9FBF]/.test(joined);
  const hasLatin = /[A-Za-z]/.test(joined);
  const codeSwitch = hasCjk && hasLatin;

  if (charCount > 4000 || messages.length > 20) {
    return 'deep-context';
  }
  if (codeSwitch || /zh|yue|hk/i.test(targetLanguage)) {
    return 'edge-realtime';
  }
  return 'edge-realtime';
}

function safeParseLLMJSON(text: string): Partial<AnalyzeIntentResponse> {
  const trimmed = text.trim();

  try {
    return JSON.parse(trimmed) as Partial<AnalyzeIntentResponse>;
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    if (!match) {
      return {};
    }
    try {
      return JSON.parse(match[0]) as Partial<AnalyzeIntentResponse>;
    } catch {
      return {};
    }
  }
}

function fallbackResponse(latencyMs: number, tier: ModelTier): AnalyzeIntentResponse {
  return {
    subtext_explanation: '我整理咗語氣，建議先用較柔和句式。',
    suggestions: [
      { tone: 'gentle', text: '我明白你嘅感受，等我解釋下。', confidence: 0.78 },
      { tone: 'empathetic', text: '多謝你講清楚，我想同你慢慢傾。', confidence: 0.76 },
      { tone: 'direct', text: '我聽到你重點，我會直接回應。', confidence: 0.74 },
    ],
    health_delta: 0,
    latency_ms: latencyMs,
    detected_emotion: 'neutral',
    model_tier: tier,
  };
}

function toneLabelForTier(tier: ModelTier): string {
  switch (tier) {
    case 'deep-context':
      return 'Deep context coaching';
    case 'edge-realtime':
      return 'Realtime coaching';
    default:
      return 'Local quick assist';
  }
}

async function callGemini(
  env: Env,
  tier: ModelTier,
  targetLanguage: string,
  draft: string,
  scrubbedMessages: string[]
): Promise<AnalyzeIntentResponse> {
  const start = Date.now();

  const systemPrompt = [
    'You are RelateOS, a Hong Kong relationship communication coach.',
    `Execution tier: ${toneLabelForTier(tier)}.`,
    'Support Cantonese/English code-switching and face-saving communication.',
    'Return strict JSON only with keys: subtext_explanation, suggestions, health_delta, detected_emotion.',
    'suggestions must be an array of exactly 3 items with {tone,text,confidence}. text <= 40 chars when possible.',
  ].join(' ');

  const userPrompt = [
    `target_language=${targetLanguage}`,
    `draft=${draft || '(empty)'}`,
    'context_messages=',
    scrubbedMessages.join('\n'),
  ].join('\n');

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        system_instruction: {
          role: 'system',
          parts: [{ text: systemPrompt }],
        },
        contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
      }),
    }
  );

  const latency = Date.now() - start;
  if (!response.ok) {
    return fallbackResponse(latency, tier);
  }

  const data = (await response.json()) as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  };

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
  const parsed = safeParseLLMJSON(text);
  const suggestions = Array.isArray(parsed.suggestions) ? parsed.suggestions.slice(0, 3) : [];

  if (suggestions.length === 0) {
    return fallbackResponse(latency, tier);
  }

  return {
    subtext_explanation:
      typeof parsed.subtext_explanation === 'string'
        ? parsed.subtext_explanation
        : '我幫你整理成較容易被對方接收嘅語氣。',
    suggestions: suggestions.map((item) => ({
      tone: typeof (item as SuggestionItem).tone === 'string' ? (item as SuggestionItem).tone : 'gentle',
      text: String((item as SuggestionItem).text || '').slice(0, 60),
      confidence:
        typeof (item as SuggestionItem).confidence === 'number'
          ? (item as SuggestionItem).confidence
          : 0.75,
    })),
    health_delta:
      typeof parsed.health_delta === 'number'
        ? Math.max(-1, Math.min(1, parsed.health_delta))
        : 0,
    latency_ms: latency,
    detected_emotion:
      typeof parsed.detected_emotion === 'string' ? parsed.detected_emotion : 'neutral',
    model_tier: tier,
  };
}

async function handleAnalyzeIntent(request: Request, env: Env): Promise<AnalyzeIntentResponse> {
  const start = Date.now();
  const incoming = await maybeDecryptRequest(request, env);
  const normalized = normalizeRequest(incoming);

  await enforceRateLimit(normalized.userId, env);

  const scrubbedMessages = normalized.contextMessages.map(recapRedact);
  const scrubbedDraft = recapRedact(normalized.draft);
  const tier = selectModelTier(scrubbedDraft, scrubbedMessages, normalized.targetLanguage);

  const cacheKey = await cacheKeyForRequest(
    tier,
    normalized.targetLanguage,
    scrubbedDraft,
    scrubbedMessages
  );

  if (env.CACHE_STORE) {
    const cached = await env.CACHE_STORE.get(cacheKey);
    if (cached) {
      try {
        const parsed = JSON.parse(cached) as AnalyzeIntentResponse;
        return {
          ...parsed,
          latency_ms: Date.now() - start,
        };
      } catch {
        // Ignore corrupted cache entries.
      }
    }
  }

  if (!env.GEMINI_API_KEY) {
    return fallbackResponse(Date.now() - start, tier);
  }

  const llm = await callGemini(
    env,
    tier,
    normalized.targetLanguage,
    scrubbedDraft,
    scrubbedMessages
  );

  const result = {
    ...llm,
    latency_ms: Date.now() - start,
  };

  if (env.CACHE_STORE) {
    // Short TTL to keep suggestions fresh while still cutting duplicate calls.
    await env.CACHE_STORE.put(cacheKey, JSON.stringify(result), { expirationTtl: 180 });
  }

  return result;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return jsonResponse({ ok: true }, 204);
    }

    const url = new URL(request.url);
    const wantsEncryptedResponse = (request.headers.get('Content-Type') || '').includes('application/octet-stream');

    try {
      if (request.method === 'POST' && (url.pathname === '/analyze-intent' || url.pathname === '/api/v1/analyze-intent')) {
        const response = await handleAnalyzeIntent(request, env);
        if (wantsEncryptedResponse) {
          return encryptedJSONResponse(response, request, env, 200);
        }
        return jsonResponse(response, 200);
      }

      if (request.method === 'GET' && url.pathname === '/health') {
        return jsonResponse({ status: 'ok', service: 'relateos-ai-proxy' }, 200);
      }

      return jsonResponse({ error: 'Not found' }, 404);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Internal server error';
      return jsonResponse({ error: message }, 500);
    }
  },
};

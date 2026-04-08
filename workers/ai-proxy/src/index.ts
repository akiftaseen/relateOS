// relateos-ai-proxy
// Cloudflare Workers Edge Function for AI routing and PII scrubbing
// Deploy with: wrangler publish

// Environment variables required:
// GEMINI_API_KEY: Google Gemini 2.5 Pro API key
// PORT_RATE_LIMIT: 60 requests per minute per user

const GEMINI_MODEL = 'gemini-2.5-pro';
const RATE_LIMIT_PER_MIN = 60;
const RATE_LIMIT_WINDOW = 60 * 1000; // milliseconds

interface AnalyzeIntentRequest {
  user_id: string;
  context_messages: string[];
  target_language: string;
  current_draft?: string;
}

interface SuggestionItem {
  tone: string;
  text: string;
}

interface AnalyzeIntentResponse {
  subtext_explanation: string;
  suggestions: SuggestionItem[];
  health_delta: number;
  latency_ms: number;
  detected_emotion: string;
}

async function handleAnalyzeIntent(
  request: AnalyzeIntentRequest,
  env: Env,
  ctx: ExecutionContext
): Promise<AnalyzeIntentResponse> {
  const startTime = Date.now();

  // Rate limiting: check rate limit via Durable Objects or KV
  const userId = request.user_id;
  const rateLimitKey = `rate_limit:${userId}`;
  
  const limitData = await env.RATE_LIMIT_STORE.get(rateLimitKey);
  let requestCount = 0;
  if (limitData) {
    const data = JSON.parse(limitData);
    if (Date.now() - data.timestamp < RATE_LIMIT_WINDOW) {
      requestCount = data.count;
    }
  }
  
  if (requestCount >= RATE_LIMIT_PER_MIN) {
    throw new Error('Rate limit exceeded: 60 requests per minute');
  }
  
  // Update rate limit store
  await env.RATE_LIMIT_STORE.put(
    rateLimitKey,
    JSON.stringify({
      count: requestCount + 1,
      timestamp: Date.now(),
    }),
    { expirationTtl: 60 }
  );

  // Scrub PII from messages
  const scrubbedMessages = request.context_messages.map(msg =>
    scrubbePII(msg)
  );

  // Build Gemini prompt
  const systemPrompt = `You are RelateOS, a Hong Kong relationship coach. Analyze the following chat in context of Cantonese/English code-switching and face-saving culture. Never translate slang literally. Output only JSON with keys: subtext_explanation, suggestions (array of 3 objects with tone and text <=40 chars), health_delta (0-1), detected_emotion.`;

  const userPrompt = `Language: ${request.target_language}\n\nMessages:\n${scrubbedMessages.join('\n')}\n\nCurrent draft: ${request.current_draft || 'none'}`;

  // Call Gemini 2.5 Pro
  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        system_instruction: {
          parts: { text: systemPrompt },
        },
        contents: [
          {
            parts: { text: userPrompt },
          },
        ],
      }),
    }
  );

  if (!geminiResponse.ok) {
    throw new Error(`Gemini API error: ${geminiResponse.statusText}`);
  }

  const geminiData = await geminiResponse.json();
  const responseText = geminiData.contents[0]?.parts[0]?.text || '{}';
  const parsedResponse = JSON.parse(responseText);

  const latencyMs = Date.now() - startTime;

  return {
    subtext_explanation: parsedResponse.subtext_explanation || '',
    suggestions: parsedResponse.suggestions || [],
    health_delta: parsedResponse.health_delta || 0,
    latency_ms: latencyMs,
    detected_emotion: parsedResponse.detected_emotion || 'neutral',
  };
}

function scrubbePII(text: string): string {
  // Replace names, emails, phone numbers, HKID
  let scrubbed = text;

  // HKID pattern (X123456(A))
  scrubbed = scrubbed.replace(
    /[A-Z]\d{6}\([A0-9]\)/gi,
    '[REDACTED_ID]'
  );

  // Email pattern
  scrubbed = scrubbed.replace(
    /[^\s@]+@[^\s@]+\.[^\s@]+/gi,
    '[REDACTED_EMAIL]'
  );

  // Hong Kong phone pattern (8 digits or +852 format)
  scrubbed = scrubbed.replace(
    /(\+852\s?|00852\s?)?[2-9]\d{7}/g,
    '[REDACTED_PHONE]'
  );

  // MTR stations -> Generic tags
  const mtrStations: Record<string, string> = {
    'Causeway Bay': '[Commercial District]',
    'Central': '[Business District]',
    'Victoria Peak': '[Tourist Landmark]',
    'Hong Kong Island': '[Location]',
    'Kowloon': '[Location]',
    'New Territories': '[Location]',
  };

  for (const [station, tag] of Object.entries(mtrStations)) {
    scrubbed = scrubbed.replace(
      new RegExp(station, 'gi'),
      tag
    );
  }

  // Generic address redaction
  scrubbed = scrubbed.replace(
    /\d+\s+[A-Za-z]{2,}\s+(Road|Street|Lane|Avenue|Drive|Court)/gi,
    '[Location]'
  );

  return scrubbed;
}

interface Env {
  GEMINI_API_KEY: string;
  RATE_LIMIT_STORE: KVNamespace;
  SECRETS: {
    ENCRYPTION_KEY: string;
  };
}

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);
    const method = request.method;

    // CORS headers
    const headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    };

    if (method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    try {
      if (url.pathname === '/api/v1/analyze-intent' && method === 'POST') {
        const body = await request.json() as AnalyzeIntentRequest;
        const response = await handleAnalyzeIntent(body, env, ctx);

        return new Response(JSON.stringify(response), {
          status: 200,
          headers,
        });
      }

      if (url.pathname === '/health' && method === 'GET') {
        return new Response(JSON.stringify({ status: 'ok' }), {
          status: 200,
          headers,
        });
      }

      return new Response(JSON.stringify({ error: 'Not found' }), {
        status: 404,
        headers,
      });
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(
        JSON.stringify({
          error: error instanceof Error ? error.message : 'Internal server error',
        }),
        {
          status: 500,
          headers,
        }
      );
    }
  },
};

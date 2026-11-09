"""Small Gemini REST adapter; API keys stay in headers and never enter request URLs."""
import json
import re
from types import SimpleNamespace
from urllib.request import Request, urlopen


class GeminiModel:
    def __init__(self, api_key, model, json_response=False):
        if not api_key or not re.fullmatch(r'[a-zA-Z0-9._-]+', model):
            raise ValueError('A Gemini key and valid model ID are required')
        self.api_key, self.model = api_key, model
        self.json_response = json_response

    def generate_content(self, content, request_options=None, token_budget=None, response_schema=None):
        parts = [{'text': content}] if isinstance(content, str) else [
            {'inlineData': {'mimeType': part['inline_data']['mime_type'], 'data': part['inline_data']['data']}}
            if 'inline_data' in part else part for part in content]
        body = {'contents': [{'role': 'user', 'parts': parts}],
                'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 3000,
                                     'thinkingConfig': {'thinkingBudget': 0}}}
        if self.json_response:
            body['generationConfig']['responseMimeType'] = 'application/json'
        if response_schema is not None:
            body['generationConfig']['responseMimeType'] = 'application/json'
            body['generationConfig']['responseSchema'] = response_schema
        if token_budget is not None:
            count_request = Request(f'https://generativelanguage.googleapis.com/v1beta/models/{self.model}:countTokens',
                data=json.dumps({'contents': body['contents']}).encode(),
                headers={'x-goog-api-key': self.api_key, 'Content-Type': 'application/json'})
            with urlopen(count_request, timeout=10) as response:
                input_tokens = json.load(response)['totalTokens']
            available = token_budget - input_tokens - 32
            if available < 64:
                raise RuntimeError('The reserved token budget cannot cover this context')
            body['generationConfig']['maxOutputTokens'] = min(3000, available)
        request = Request(f'https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent',
                          data=json.dumps(body).encode(), headers={'x-goog-api-key': self.api_key, 'Content-Type': 'application/json'})
        with urlopen(request, timeout=(request_options or {}).get('timeout', 20)) as response:
            result = json.load(response)
        candidates = result.get('candidates', [])
        text = ''.join(p.get('text', '') for p in candidates[0].get('content', {}).get('parts', [])) if candidates else ''
        if not text.strip():
            raise RuntimeError('Gemini returned no usable content')
        usage = result.get('usageMetadata', {}).get('totalTokenCount')
        if token_budget is not None and (not isinstance(usage, int) or usage > token_budget):
            raise RuntimeError('Provider usage exceeds the reserved token budget')
        return SimpleNamespace(text=text, usage_metadata=SimpleNamespace(
            total_token_count=usage))

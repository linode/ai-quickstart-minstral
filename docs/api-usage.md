# API Usage

AI Quickstart - Minstral LLM provides a fully OpenAI-compatible REST API endpoint, making it a drop-in replacement for OpenAI's API. Simply change your `BASE_URL` to point to your instance.

## Endpoint

- **Base URL**: `http://YOUR_INSTANCE_IP:8000/v1`
- **API Version**: Compatible with OpenAI API v1

## Authentication

**No authentication required**: The API is accessible without any credentials or API keys. You can make requests directly to the endpoint.

⚠️ **Security Note**: Since there's no authentication, you must configure a Linode Cloud Firewall to restrict access. See the [Security Guide](security.md) for details.

## Chat Completions

The primary endpoint for chat-based interactions.

### Endpoint

```
POST /v1/chat/completions
```

### Example Request

```bash
curl http://YOUR_INSTANCE_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistralai/Mistral-7B-Instruct-v0.3",
    "messages": [
      {"role": "user", "content": "Hello! Can you explain what AI is?"}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

### Request Parameters

- `model` (string, required): The model ID (should match the model deployed on your instance)
- `messages` (array, required): Array of message objects with `role` and `content`
- `temperature` (float, optional): Sampling temperature (0.0 to 2.0)
- `max_tokens` (integer, optional): Maximum tokens to generate
- `stream` (boolean, optional): Enable streaming responses

### Example Response

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "mistralai/Mistral-7B-Instruct-v0.3",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "AI, or Artificial Intelligence, refers to..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 50,
    "total_tokens": 60
  }
}
```

## Using with OpenAI SDK

Since the API is OpenAI-compatible, you can use it with the OpenAI Python SDK:

```python
from openai import OpenAI

# Point to your instance instead of OpenAI
client = OpenAI(
    base_url="http://YOUR_INSTANCE_IP:8000/v1",
    api_key="not-needed"  # Not used, but required by SDK
)

response = client.chat.completions.create(
    model="mistralai/Mistral-7B-Instruct-v0.3",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)
```

## Using with JavaScript/TypeScript

```javascript
const response = await fetch('http://YOUR_INSTANCE_IP:8000/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'mistralai/Mistral-7B-Instruct-v0.3',
    messages: [
      { role: 'user', content: 'Hello!' }
    ],
  }),
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

## Available Endpoints

The API supports the following OpenAI-compatible endpoints:

- `POST /v1/chat/completions` - Chat completions
- `GET /v1/models` - List available models
- `GET /health` - Health check endpoint

## Model Information

To see what model is currently deployed on your instance:

```bash
curl http://YOUR_INSTANCE_IP:8000/v1/models
```

## Troubleshooting

If you encounter issues:

1. **Verify the service is running**:
   ```bash
   curl http://YOUR_INSTANCE_IP:8000/health
   ```

2. **Check the model name** matches what's deployed on your instance

3. **Verify firewall rules** allow access to port 8000

4. **Check service logs** (SSH into instance):
   ```bash
   cd /opt/ai-sandbox
   docker-compose logs api
   ```


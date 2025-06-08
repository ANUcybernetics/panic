# Testing with API Keys

## Overview

Tests that require real API credentials (OpenAI, Replicate) are automatically
excluded by default to prevent unnecessary API usage and costs. These tests are
tagged with `api_required: true`.

## Running Tests

### Default Test Run (No API Keys)

```bash
mix test
```

This will run all tests except those requiring API keys. You'll see output like:

```
Excluding tags: [api_required: true]
```

### Running Tests with Real API Keys

To run tests that require real API credentials, set the environment variables:

```bash
OPENAI_API_KEY=your_real_openai_key REPLICATE_API_KEY=your_real_replicate_key mix test
```

### Running Only API Tests

To run only the tests that require API keys:

```bash
OPENAI_API_KEY=your_real_openai_key REPLICATE_API_KEY=your_real_replicate_key mix test --only api_required
```

## Test Database Seeding

The seeds file (`priv/repo/seeds.exs`) creates a default user and seeds API
tokens from the application configuration.

For tests requiring real API keys, the test fixtures (`user_with_real_tokens`)
will read API keys directly from environment variables at test runtime.

## API Key Configuration

### Test Environment

When running tests:

- Tests tagged with `api_required: true` will only run if both `OPENAI_API_KEY`
  and `REPLICATE_API_KEY` environment variables are set
- These tests will fail immediately if the required environment variables are
  not present
- Tests without this tag use dummy tokens from the test configuration

### Production/Development

In production and development, configure API keys through the application
configuration or by setting tokens directly on user accounts.

## Important Notes

1. **Cost Warning**: Tests with `api_required: true` will consume real API
   credits when run with real keys
2. **Opt-in Only**: API tests will fail (not skip) if environment variables
   aren't set - this is intentional to ensure you're aware when running them
3. **CI/CD**: Don't set real API keys in CI unless you want to run integration
   tests
4. **Security**: Never commit real API keys to version control

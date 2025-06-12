# Panic Testing Strategy

This document outlines the testing strategy for the Panic project, including
conventions, patterns, and guidelines for writing tests.

## Overview

The Panic project uses a comprehensive testing approach that includes unit
tests, integration tests, and feature tests. The test suite is designed to be
fast, reliable, and maintainable by using dummy models for most tests and only
requiring real API keys for specific platform integration tests.

## Key Testing Principles

### 1. Dummy Models by Default

**All tests use dummy models and networks except for `platforms_test.exs`**.
This ensures:

- Tests run quickly without making external API calls
- Tests are deterministic and reliable
- No API rate limits or costs during testing
- Tests can run in CI/CD without API keys

The dummy platform (`Panic.Platforms.Dummy`) provides models for all
input/output type combinations:

- Text-to-text, text-to-image, text-to-audio
- Image-to-text, image-to-image, image-to-audio
- Audio-to-text, audio-to-image, audio-to-audio

### 2. Real API Tests

Only `platforms_test.exs` uses real API models and is tagged with
`@describetag apikeys: true`. These tests:

- Verify actual platform integrations (OpenAI, Replicate, Gemini)
- Are excluded by default when running `mix test`
- Can be run explicitly with `mix test --include apikeys:true`
- Require environment variables: `OPENAI_API_KEY`, `REPLICATE_API_KEY`,
  `GOOGLE_AI_STUDIO_TOKEN`

### 3. PhoenixTest for Web Testing

**Web routes and user interactions should be tested via PhoenixTest whenever
possible**. PhoenixTest provides:

- A unified API for testing both LiveView and static pages
- User-centric testing approach (click, fill_in, submit, etc.)
- Better readability compared to low-level LiveView testing

Example:

```elixir
conn
|> visit("/users/#{user.id}")
|> click_link("Add network")
|> fill_in("Name", with: "Test network")
|> submit()
|> assert_has("#network-list", text: "Test network")
```

## Test Organization

### Unit Tests

- `panic/test/panic/` - Core business logic tests
  - `invocation_test.exs` - Invocation CRUD and validation
  - `network_test.exs` - Network management
  - `model_test.exs` - Model definitions and utilities
  - `users_test.exs` - User and token management
  - `engine_network_runner_test.exs` - Network execution engine

### Integration Tests

- `panic/test/panic/platforms_test.exs` - Real platform API integration tests
  (requires API keys)

### Feature Tests

- `panic/test/panic_web/live/` - LiveView and user interaction tests
  - `user_live_test.exs` - User dashboard functionality
  - `network_live_test.exs` - Network management UI
  - `terminal_live_test.exs` - Terminal interface
  - `network_live/info_test.exs` - QR code and network info
  - `network_live/terminal_test.exs` - Terminal access and token validation

## Test Helpers and Generators

### Generators (`Panic.Generators`)

StreamData generators for property-based testing:

- `user/0`, `user_with_real_tokens/0` - User generation
- `network/1`, `network_with_dummy_models/1` - Network generation
- `model/1` - Model selection with filters
- `invocation/1` - Invocation generation

### Fixtures (`Panic.Fixtures`)

Pre-generated test data:

- `user/0`, `user/1` - Create test users
- `network/1`, `network_with_dummy_models/1` - Create test networks
- `user_with_real_tokens/0` - Users with API tokens (for apikeys tests)

### Web Helpers (`PanicWeb.Helpers`)

- `create_and_sign_in_user/1` - Create and authenticate user
- `create_and_sign_in_user_with_real_tokens/1` - For API key tests
- `stop_all_network_runners/0` - Clean up GenServer processes between tests

## Current Issues and Improvements Needed

### 1. Fix terminal_live_test.exs

**Issue**: The test uses `@describetag apikeys: true` and
`create_and_sign_in_user_with_real_tokens` but then creates a network with dummy
models. This is inconsistent and unnecessary.

**Fix needed**: Remove the apikeys tag and use regular user creation:

```elixir
# Remove: @describetag apikeys: true
# Change: setup {PanicWeb.Helpers, :create_and_sign_in_user_with_real_tokens}
# To: setup {PanicWeb.Helpers, :create_and_sign_in_user}
```

### 2. Standardize on PhoenixTest

Some tests still use `Phoenix.LiveViewTest` directly instead of PhoenixTest:

- `network_live/info_test.exs`
- `network_live/terminal_test.exs`

These should be refactored to use PhoenixTest's higher-level API for consistency
and better readability.

### 3. LiveSelect Testing

As noted in comments, PhoenixTest doesn't yet support LiveSelect components
well. Current workaround is to create networks with pre-configured models rather
than testing the model selection UI.

## Running Tests

```bash
# Run all tests (excluding API tests)
mix test

# Run tests with real API calls
mix test --include apikeys:true

# Run specific test file
mix test test/panic/invocation_test.exs

# Run with coverage
mix test --cover
```

## Best Practices

1. **Always use dummy models** unless specifically testing platform integrations
2. **Use property-based testing** with ExUnitProperties where appropriate
3. **Clean up resources** - Use `on_exit` callbacks to stop processes and clean
   state
4. **Test from the user's perspective** - Use PhoenixTest's semantic actions
5. **Keep tests focused** - Each test should verify one specific behavior
6. **Use descriptive test names** - Tests should document expected behavior
7. **Avoid testing implementation details** - Focus on public APIs and
   user-visible behavior

## Test Coverage Goals

- Unit tests for all Ash actions and validations
- Integration tests for each external platform
- Feature tests for all user-facing functionality
- Property tests for data generators and validations
- Error case coverage for authorization and validation failures

## Future Improvements

1. Migrate remaining Phoenix.LiveViewTest usage to PhoenixTest
2. Add support for testing LiveSelect components in PhoenixTest
3. Improve test performance by better parallelization
4. Add visual regression testing for UI components
5. Implement contract testing for external API integrations

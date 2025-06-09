# Testing Refactor Summary

This document describes the testing refactor completed on the Panic project to
simplify and clarify the test suite.

## Changes Made

### 1. Consolidated Test Helpers

- Removed `test/support/test_helpers.ex`
- Consolidated all test helpers into `test/test_helper.exs` following ExUnit
  conventions
- Removed the `Panic.TestHelpers` module that was checking for API tokens via
  `Application.get_env`

### 2. Simplified User Fixtures

- Removed `user_with_tokens` fixture and generator that was mixing test tokens
  with real tokens
- Removed all references to `Application.get_env(:panic, :api_tokens)` which was
  never properly configured
- Created clear separation:
  - `user()` - Creates a user without any API tokens (for most tests)
  - `user_with_real_tokens()` - Creates a user with real API tokens from
    environment variables (for `api_required` tests only)

### 3. Simplified Network Fixtures

- Renamed `network_with_models` to `network_with_dummy_models` for clarity
- Most tests now use `network_with_dummy_models` which creates networks using
  only Dummy platform models
- Only `api_required` tests use `network_with_real_models`

### 4. Updated Web Helpers

- Added `create_and_sign_in_user_with_real_tokens` for LiveView tests that
  require real API calls
- Regular `create_and_sign_in_user` no longer sets any tokens

## Testing Approach

### For Regular Tests (Default)

Most tests should use Dummy models which don't require API tokens:

```elixir
test "something with a network" do
  user = Panic.Fixtures.user()
  network = Panic.Fixtures.network_with_dummy_models(user)

  # Test logic here - no API calls will be made
end
```

### For API Integration Tests

Tests that need to verify real platform integrations should be tagged with
`api_required: true`:

```elixir
@tag api_required: true
test "real API integration" do
  user = Panic.Fixtures.user_with_real_tokens()
  network = Panic.Fixtures.network_with_real_models(user)

  # Test logic here - will make real API calls
end
```

These tests will:

- Only run when `OPENAI_API_KEY` and `REPLICATE_API_KEY` environment variables
  are set
- Fail with a clear error message if the required API keys are not available
- Use real API tokens exclusively from environment variables

### Benefits

1. **Faster Tests**: Most tests use Dummy models with no network calls
2. **Clear Separation**: It's obvious which tests require real APIs
3. **No Configuration Confusion**: Real tokens only come from environment
   variables
4. **Deterministic Testing**: Dummy models produce predictable outputs for
   reliable testing

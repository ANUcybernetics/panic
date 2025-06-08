# Testing with Dummy Models

## Overview

The Panic application includes a `Panic.Platforms.Dummy` module that provides
deterministic, fast models for testing. These dummy models simulate all
input/output type combinations without making any external API calls, making
tests faster, more reliable, and cost-free.

## Why Use Dummy Models?

1. **Speed**: No network requests means tests run much faster
2. **Reliability**: No external dependencies means tests don't fail due to API
   issues
3. **Cost**: No API calls means no usage charges during testing
4. **Determinism**: Same input always produces the same output
5. **Coverage**: All input/output type combinations are supported

## Available Dummy Models

The following dummy models are available:

| Model ID    | Input Type | Output Type | Description                           |
| ----------- | ---------- | ----------- | ------------------------------------- |
| `dummy-t2t` | text       | text        | Text transformation (reverses input)  |
| `dummy-t2i` | text       | image       | Generates dummy image URL from text   |
| `dummy-t2a` | text       | audio       | Generates dummy audio URL from text   |
| `dummy-i2t` | image      | text        | Generates caption from image URL      |
| `dummy-i2i` | image      | image       | Transforms image URL to new image URL |
| `dummy-i2a` | image      | audio       | Generates audio URL from image        |
| `dummy-a2t` | audio      | text        | Generates transcript from audio URL   |
| `dummy-a2i` | audio      | image       | Generates image URL from audio        |
| `dummy-a2a` | audio      | audio       | Transforms audio URL to new audio URL |

## Default Test Behavior

By default, tests use dummy models unless specifically configured otherwise:

- Property tests using `Panic.Generators.model()` will prefer dummy models
- Network generators (`network_with_models`) create networks with dummy models
- Test fixtures create users with dummy tokens that work with dummy models

## Using Real Models in Tests

For tests that need to verify actual API integration, use the
`@tag api_required: true` tag:

```elixir
describe "API integration tests" do
  @describetag api_required: true

  test "real model produces output" do
    user = Panic.Fixtures.user_with_real_tokens()
    network = Panic.Fixtures.network_with_real_models(user)
    # ... test with real API calls
  end
end
```

Tests with `api_required: true` are automatically excluded unless real API keys
are available via environment variables:

- `OPENAI_API_KEY`
- `REPLICATE_API_KEY`

## Example Output

Dummy models produce predictable outputs:

- **Text outputs**: Prefixed with `DUMMY_TEXT:`, `DUMMY_CAPTION:`,
  `DUMMY_TRANSCRIPT:`, or `DUMMY_DESCRIPTION:`
- **Image outputs**: URLs like `https://dummy-images.test/{hash}.png`
- **Audio outputs**: URLs like `https://dummy-audio.test/{hash}.ogg`

## Testing Networks with Dummy Models

```elixir
# Create a network with dummy models
network =
  user
  |> Panic.Fixtures.network()
  |> Panic.Engine.update_models!([["dummy-t2i"], ["dummy-i2t"]], actor: user)

# Run the network
invocation =
  network
  |> Panic.Engine.prepare_first!("test input", actor: user)
  |> Panic.Engine.invoke!(actor: user)

# Output will be a dummy image URL
assert String.starts_with?(invocation.output, "https://dummy-images.test/")
```

## Property Testing

The generators automatically use dummy models for efficiency:

```elixir
property "networks process input correctly" do
  user = Panic.Fixtures.user()

  check all(
    network <- Panic.Generators.network_with_models(user),
    input <- Panic.Generators.ascii_sentence()
  ) do
    # This will use dummy models by default
    invocation = Panic.Engine.prepare_first!(network, input, actor: user)
    assert invocation.input == input
  end
end
```

## Running Tests

```bash
# Run all tests (excludes api_required tests by default)
mix test

# Run only tests that use dummy models
mix test --exclude api_required

# Run tests including real API tests (requires API keys)
OPENAI_API_KEY=sk-... REPLICATE_API_KEY=r8_... mix test
```

## Best Practices

1. **Use dummy models by default**: They're faster and more reliable
2. **Tag API tests appropriately**: Use `@tag api_required: true` for tests that
   need real models
3. **Test both paths**: Have some tests with dummy models and some with real
   models
4. **Check output patterns**: Dummy outputs have predictable patterns you can
   assert against
5. **Keep API tests focused**: Only test what specifically needs real API
   interaction

## Extending Dummy Models

If you need to modify dummy model behavior, edit `lib/panic/platforms/dummy.ex`.
The module uses pattern matching on input/output types to generate appropriate
responses.

Each dummy model:

- Accepts the same inputs as real models
- Returns the same output format
- Produces deterministic results based on input
- Never makes network requests
- Always succeeds (unless given invalid type combinations)

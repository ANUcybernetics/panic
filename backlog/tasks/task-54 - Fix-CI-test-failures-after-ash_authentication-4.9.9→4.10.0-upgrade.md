---
id: task-54
title: Fix CI test failures after ash_authentication 4.9.9→4.10.0 upgrade
status: To Do
assignee: []
created_date: '2025-10-02 12:26'
labels:
  - bug
  - ci
  - ash_authentication
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

After upgrading ash_authentication from 4.9.9 to 4.10.0 (commit b52ada5), CI tests fail with:

```
** (MatchError) no match of right hand side value: :error
    at AshAuthentication.GenerateTokenChange.generate_token/4
```

Tests pass locally but fail in CI during user registration in test setup.

## Root Cause

The `Panic.Secrets.secret_for/4` callback uses `Application.fetch_env(:panic, :token_signing_secret)` which returns `{:error, :not_found}` when the config key is missing. However, the `AshAuthentication.Secret` behaviour expects the callback to return either `{:ok, String.t()}` or `:error` (the atom, not an error tuple).

From the AshAuthentication.Secret documentation:
```elixir
@callback secret_for(
  secret_name :: [atom()],
  resource :: Ash.Resource.t(),
  options :: keyword(),
  context :: map()
) :: {:ok, String.t()} | :error
```

The current implementation in lib/panic/secrets.ex:
```elixir
def secret_for([:authentication, :tokens, :signing_secret], Panic.Accounts.User, _opts, _context) do
  Application.fetch_env(:panic, :token_signing_secret)
end
```

This directly returns the result of `Application.fetch_env/2`, which returns `{:error, :not_found}` on failure, causing a pattern match error in ash_authentication 4.10.0's internal code that expects only `:error` (not `{:error, _}`).

## Why It Works Locally But Fails in CI

1. Locally, config/test.exs sets `config :panic, token_signing_secret: "..."` which loads successfully
2. In CI, the aggressive build caching (caching both deps and _build) may cause:
   - Stale compiled code with incorrect configuration assumptions
   - Config loading order issues during test compilation
   - The secret callback being called before config/test.exs is fully loaded

## Solution

Update lib/panic/secrets.ex to handle the error tuple and convert it to the expected `:error` atom:

```elixir
def secret_for([:authentication, :tokens, :signing_secret], Panic.Accounts.User, _opts, _context) do
  case Application.fetch_env(:panic, :token_signing_secret) do
    {:ok, secret} -> {:ok, secret}
    {:error, _} -> :error
  end
end
```

This is not a hack---it's the correct implementation according to the AshAuthentication.Secret behaviour specification.

## Steps to Reproduce

1. Upgrade ash_authentication from 4.9.9 to 4.10.0
2. Run tests in CI with cached builds
3. Observe MatchError during user registration

## Testing the Fix

1. Update lib/panic/secrets.ex with the case statement above
2. Run `mix test` locally to verify tests still pass
3. Clear CI caches and re-run to verify fix
4. Monitor subsequent CI runs with cached builds

## References

- ash_authentication 4.10.0 changelog: https://github.com/team-alembic/ash_authentication/blob/main/CHANGELOG.md
- AshAuthentication.Secret docs: https://hexdocs.pm/ash_authentication/AshAuthentication.Secret.html
- Commit that triggered issue: b52ada5 (deps.update)
<!-- SECTION:DESCRIPTION:END -->

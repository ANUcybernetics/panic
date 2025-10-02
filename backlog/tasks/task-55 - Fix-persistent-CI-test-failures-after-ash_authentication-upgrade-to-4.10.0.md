---
id: task-55
title: Fix persistent CI test failures after ash_authentication upgrade to 4.10.0
status: To Do
assignee: []
created_date: '2025-10-02 12:35'
labels:
  - bug
  - ci
  - ash_authentication
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
All tests pass locally but fail in CI after upgrading ash_authentication from 4.9.9 to 4.10.0 with a MatchError in AshAuthentication.GenerateTokenChange.generate_token/4.

## Background
- All tests pass locally (mix test shows 0 failures)
- All tests fail in CI with the same error: ** (MatchError) no match of right hand side value: :error in AshAuthentication.GenerateTokenChange.generate_token/4
- The error occurs during user registration in test setup
- lib/panic/secrets.ex is configured to fetch token signing secret via Application.fetch_env(:panic, :token_signing_secret)
- config/test.exs sets config :panic, token_signing_secret: "lR3r6rkW8nRkChM35qcKl00FNSK95ra5"

## Attempted Fixes (all failed in CI)
1. Added TOKEN_SIGNING_SECRET environment variable to CI workflow (.github/workflows/elixir-ci.yml) - did not help
2. Fixed lib/panic/secrets.ex to properly handle :error atom instead of {:error, _} tuple - tests still fail in CI
3. Cleared CI caches multiple times - no effect
4. Tried adding Mix.env() check fallback in lib/panic/secrets.ex - reverted as it was a hack

## Current State
- Commit 0b5e2ea has the proper fix for the return type (handling :error atom)
- Tests pass locally but fail in CI with exact same error
- This suggests config/test.exs is not being loaded or Application.fetch_env is returning :error in CI for some reason
- lib/panic/secrets.ex now has proper error handling but the underlying config issue remains
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Identify why Application.fetch_env returns :error in CI when config/test.exs clearly sets the value
- [ ] #2 All tests pass in CI after the fix
- [ ] #3 Fix is minimal and does not involve hacky Mix.env() checks
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What Needs Investigation
1. Why is Application.fetch_env returning :error in CI when config/test.exs clearly sets the value?
2. Is there a config loading order issue in CI?
3. Is runtime.exs interfering with test.exs config in CI but not locally?
4. Do we need a different approach for test configuration in ash_authentication 4.10.0?
5. Compare the exact test setup process between local and CI environments
6. Check if ash_authentication 4.10.0 changed how it expects token signing secrets to be configured

## Files to Review
- lib/panic/secrets.ex (current implementation with :error handling)
- config/test.exs (where token_signing_secret is set)
- config/runtime.exs (may be interfering)
- .github/workflows/elixir-ci.yml (CI configuration)
- Commit 0b5e2ea (has the current state with proper error handling)

## Potential Next Steps
1. Add debug output in CI to see what Application.get_all_env(:panic) returns during tests
2. Check if we need to explicitly compile config in CI before running tests
3. Review ash_authentication 4.10.0 changelog and migration guide for configuration changes
4. Consider using Application.put_env in test_helper.exs as a workaround if config loading is the issue
<!-- SECTION:NOTES:END -->

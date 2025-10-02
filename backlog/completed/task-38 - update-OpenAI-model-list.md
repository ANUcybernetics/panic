---
id: task-38
title: update OpenAI model list
status: Done
assignee: []
created_date: "2025-08-13 22:45"
labels: []
dependencies: []
---

## Description

Since the GPT5 release, and the deprecation of some of the older models, I'm not
sure which of the existing ones (in the OpenAI module) are still available.

1. run the PlatformsTest tests (need to set `apikeys: true`)
2. see which ones are broken
3. search the web for the current API docs, and modify the relevant model
   structs in `Panic.Model` so that there's one "cheap/nano/mini" GPT5 model,
   and one "mid-tier" GPT5 model (two OpenAI models is enough for now, delete
   all the GPT4 ones)
4. update any places in the codebase that the gpt4 ones are mentioned (e.g. in
   "network IO connctions" tests) and ensure that all tests pass

## Completion Notes

✅ Updated OpenAI platform module to support GPT-5 API requirements:
   - Changed from `max_tokens` to `max_completion_tokens` (150 tokens)
   - Set temperature to 1.0 (required for GPT-5 models)

✅ Replaced GPT-4 models with GPT-5 models in `lib/panic/model.ex`:
   - Removed `gpt-4.1` and `gpt-4.1-nano`
   - Added `gpt-5-mini` (cheap/mini tier)
   - Added `gpt-5` (mid-tier)

✅ Updated all test references:
   - `test/panic/validations/model_io_connections_test.exs`
   - `test/panic_web/live/network_live/terminal_component_test.exs`

✅ All tests pass successfully

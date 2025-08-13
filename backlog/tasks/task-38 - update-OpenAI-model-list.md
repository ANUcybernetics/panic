---
id: task-38
title: update OpenAI model list
status: To Do
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

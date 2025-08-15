---
id: task-42
title: fix model list display on network show page
status: Done
assignee: []
created_date: '2025-08-15 02:23'
updated_date: '2025-08-15 02:27'
labels: []
dependencies: []
---

## Description

The "Model list" widget on the
@lib/panic_web/live/network_live/model_select_component.ex is a bit of a mess.
I'd like to refactor it so that it's just a table (using the standard component
used in other places in this app) which has one row per model and:

- a column for the model index
- a column for the model name
- a column for the model type (colour-coded)

In addition, the message displayed when the current (in-memory) network is
invalid is way too long; make that shorter.

Add/update any tests and ensure that everything passes.

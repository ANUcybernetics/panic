---
id: task-45
title: graceful handling of deleted models
status: Done
assignee: []
created_date: "2025-08-15 06:06"
labels: []
dependencies: []
---

## Description

Since new models are added/removed all the time (to @model.ex) it's possible
that there will be a Network in the database that includes a model with a model
ID that can't be found in @model.ex .

While this network can't be run (because that model can't be invoked) I don't
want it to crash the ModelSelectComponent or the NetworkLive.Show page. Make
that page handle a "missing model" gracefully, perhaps via the same logic as the
"validate that the inputs and outputs all match" code paths.

## Solution

Implemented graceful handling for deleted models throughout the application:

1. **Added `Model.by_id/1` function** - A non-raising version of `Model.by_id!/1` that returns `nil` when a model is not found

2. **Updated ModelSelectComponent** - Now filters out missing models when loading from the network, preventing crashes when displaying saved models

3. **Updated validation logic** (`ModelIOConnections`) - Returns a descriptive error message instead of crashing when encountering missing models

4. **Fixed NetworkRunner** - Handles missing models gracefully when archiving invocations

5. **Fixed InvokeModel change** - Returns proper error instead of crashing during invocation

6. **Updated all display components** - Components that display invocations now check if the model exists before rendering, showing appropriate fallback UI for missing models

The network will now display properly even with deleted models, though it won't be runnable (which is expected). Users will see clear error messages about missing models rather than experiencing crashes.

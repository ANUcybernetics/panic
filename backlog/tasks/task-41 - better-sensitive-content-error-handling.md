---
id: task-41
title: better sensitive content error handling
status: To Do
assignee: []
created_date: "2025-08-15 01:46"
labels: []
dependencies: []
---

## Description

For the Replicate platform (@lib/panic/platforms/replicate.ex), some of the
models can return "sensitive/nsfw content" errors, however the specifics of the
error are different from model-to-model. Currently there's some handling for
this (search the codebase for `:nsfw`) but with the newly added
"image-reproducer-i-seed" model I just saw this (uncaught) error in the logs:

```
[error] Invocation processing failed: %Ash.Error.Invalid{bread_crumbs: ["Error returned from: Panic.Engine.Invocation.invoke"],  changeset: "#Changeset<>",  errors: [%Ash.Error.Changes.InvalidChanges{fields: nil, message: "The input or output was flagged as sensitive. Please try again with different inputs. (E005)", validation: nil, value: nil, splode: Ash.Error, bread_crumbs: ["Error returned from: Panic.Engine.Invocation.invoke"], vars: [], path: [], stacktrace: #Splode.Stacktrace<>, class: :invalid}]}
```

Given that there's no HTML error code for this, it seems like parsing the error
message is the best we can hope for. However, doing this in the `Replicate.get`
function seems a bit ad-hoc. Is there a nice way to handle it in e.g. the
model-specific `:invoke` function, so that at least we could customize the
detection logic per-model? Or will that require significant changes to the
codebase? If that's the case, perhaps a good compromise is to add a
`detect_nsfw` function to the `Replicate` module so that at least all of that
stuff can be in the one place.

If any changes are made, they need to have tests added and all tests must pass.

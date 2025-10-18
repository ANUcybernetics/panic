---
id: task-41
title: better sensitive content error handling
status: Done
assignee: []
created_date: '2025-08-15 01:46'
updated_date: '2025-10-17 23:53'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
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

## Progress

### Completed work (2025-08-15)

Implemented a centralized NSFW/sensitive content detection system in the Replicate platform module:

1. **Added `detect_nsfw/1` function** (@lib/panic/platforms/replicate.ex:105-140)
   - Centralizes detection logic for various NSFW error formats
   - Handles multiple patterns including:
     - Original "NSFW" prefix pattern
     - New "flagged as sensitive" pattern with error codes (E005)
     - Common variations like "inappropriate content", "explicit content", "adult content"
   - Case-insensitive matching for better coverage
   - Safe handling of non-string inputs

2. **Updated `get/2` function** (@lib/panic/platforms/replicate.ex:43-48)
   - Now uses the centralized `detect_nsfw` function
   - Returns consistent `:nsfw` error atom for all detected sensitive content errors

3. **Added comprehensive tests** (@test/panic/platforms/replicate_test.exs)
   - Tests for all detection patterns
   - Edge cases and false positive prevention
   - Non-string input handling
   - All tests passing

### Benefits

- **Consistent error handling**: All NSFW/sensitive content errors now return `:nsfw` atom
- **Centralized logic**: Easy to update detection patterns in one place
- **Model-agnostic**: Works with all Replicate models without model-specific changes
- **Extensible**: New patterns can be easily added to `detect_nsfw/1`
- **Well-tested**: Comprehensive test coverage ensures reliability

The solution successfully handles the new error format from the seededit-3.0 model while maintaining backward compatibility with existing NSFW error handling.
<!-- SECTION:DESCRIPTION:END -->

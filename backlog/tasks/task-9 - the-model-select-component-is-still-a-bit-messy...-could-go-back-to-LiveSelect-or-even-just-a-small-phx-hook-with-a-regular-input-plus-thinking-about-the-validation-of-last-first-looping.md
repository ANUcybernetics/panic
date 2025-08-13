---
id: task-9
title: >-
  the model select component is still a bit messy... could go back to
  LiveSelect, or even just a small phx-hook with a regular input (plus thinking
  about the validation of last->first looping)
status: To Do
assignee: []
created_date: "2025-07-08"
labels:
  - ui
  - refactoring
dependencies: []
---

## Description

The @lib/panic/web/live/network*live/model_select_component.ex component is
currently based on the :autocomplete_input component. However, the :live_select
component (not installed, but available through Hex) \_might* be a better fit.

The goal (for the component in this project) is to allow the user to quickly
create new networks, with only keyboard interaction (mouse is fine too, but it'd
be best to not _have_ to use it).

- cursor/focus enters model select component
- dropdown shows only matching options (intersection of "input type matches
  output of current last model in network" and fuzzy string match based on the
  current text)
- kbd ENTER (or mouse click) to select one of the candidates
- text immediately resets to an empty string, and dropdown is re-populated with
  all matching next model options (and the "output of current last model in
  network" is now the output type of the just-selected model)

The dropdown should only disappear when focus leaves the component.

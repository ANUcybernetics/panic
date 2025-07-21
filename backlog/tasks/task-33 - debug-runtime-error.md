---
id: task-33
title: debug runtime error
status: Done
assignee: []
created_date: "2025-07-21"
labels: []
dependencies: []
---

## Description

Here's a recent error I saw in prod. From the logs:

```
2025-07-21T01:36:28Z app[e78432edcd9248] syd [info]** (FunctionClauseError) no function clause matching in PanicWeb.NetworkLive.TerminalComponent.handle_event/3
2025-07-21T01:36:28Z app[e78432edcd9248] syd [info]    (panic 3.0.0-beta.0) lib/panic_web/live/network_live/terminal_component.ex:64: PanicWeb.NetworkLive.TerminalComponent.handle_event("validate", %{"_target" => ["invocation", "input"]}, #Phoenix.LiveView.Socket<id: "phx-GFQgSuljindncAbB", endpoint: PanicWeb.Endpoint, view: PanicWeb.NetworkLive.Show, parent_pid: nil, root_pid: #PID<0.8901.0>, router: PanicWeb.Router, assigns: %{id: 12, form: %Phoenix.HTML.Form{source: #AshPhoenix.Form<resource: Panic.Engine.Invocation, action: :prepare_first, type: :create, params: %{}, source: #Ash.Changeset<domain: Panic.Engine, action_type: :create, action: :prepare_first, attributes: %{state: :ready, metadata: %{}, sequence_number: 0, model: "flux-schnell"}, relationships: %{network: [{[%Panic.Engine.Network{id: 12, name: "Decoding AI", description: "Text to image, image to text, and so on and so forth.", models: ["flux-schnell", "moondream2", "imagen-3-fast", "florence-2-large", "stable-diffusion", "blip-2", "photon-flash", "blip-3"], slug: nil, lockout_seconds: 30, inserted_at: ~U[2025-07-03 23:53:37.387656Z], updated_at: ~U[2025-07-03 23:54:55.532174Z], user_id: 1, user: #Ash.NotLoaded<:relationship, field: :user>, invocations: #Ash.NotLoaded<:relationship, field: :invocations>, installations: [%Panic.Watcher.Installation{id: 4, name: "Birch Level 3", watchers: [%Panic.Watcher.Installation.Config{type: :single, name: "tv1", rows: nil, columns: nil, stride: 8, offset: 0, show_invoking: true, vestaboard_name: nil, initial_prompt: false, __meta__: #Ecto.Schema.Metadata<:built, "">}, %Panic.Watcher.Installation.Config{type: :single, name: "tv2", rows: nil, columns: nil, stride: 8, offset: 2, show_invoking: true, vestaboard_name: nil, initial_prompt: false, __meta__: #Ecto.Schema.Metadata<:built, "">}, %Panic.Watcher.Installation.Config{type: :single, name: "tv3", rows: nil, columns: nil, stride: 8, offset: 4, show_invoking: true, vestaboard_name: nil, initial_prompt: false, __meta__: #Ecto.Schema.Metadata<:built, "">}, %Panic.Watcher.Installation.Config{type: :single, name: "tv4", rows: nil, columns: nil, stride: 8, offset: 6, show_invoking: true, vestaboard_name: nil, initial_prompt: false, __meta__: #Ecto.Schema.Metadata<:built, "">}, %Panic.Watcher.Installation.Config{type: :vestaboard, name: "panic1", rows: nil, columns: nil, stride: 8, offset: 7, show_invoking: false, vestaboard_name: :panic_1, initial_prompt: true, __meta__: #Ecto.Schema.Metadata<:built, "">}, %Panic.Watcher.Installation.Config{type: :vestaboard, name: "panic2", rows: nil, columns: nil, stride: 8, offset: 1, show_invoking: false, vestaboard_name: :panic_2, initial_prompt: false, ...}, %Panic.Watcher.Installation.Config{type: :vestaboard, name: "panic3", rows: nil, columns: nil, stride: 8, offset: 3, show_invoking: false, vestaboard_name: :panic_3, ...}, %Panic.Watcher.Installation.Config{type: :vestaboard, name: "panic4", rows: nil, columns: nil, stride: 8, offset: 5, show_invoking: false, ...}], inserted_at: ~U[2025-07-03 23:55:20.704767Z], updated_at: ~U[2025-07-04 01:45:54.022779Z], network_id: 12, network: #Ash.NotLoaded<:relationship, field: :network>, __meta__: #Ecto.Schema.Metadata<:loaded, "installations">}], __meta__: #Ecto.Schema.Metadata<:loaded, "networks">}], [debug?: false, ignore?: false, on_missing: :unrelate, on_match: :ignore, on_lookup: :relate, on_no_match: :error, eager_validate_with: false, authorize?: true, type: :append_and_remove]}]}, arguments: %{network: %Panic.Engine.Network{id: 12, name: "Decoding AI", description: "Text to image, image to text, and so on and so forth.", models: ["flux-schnell", "moondrea (truncated)
2025-07-21T01:39:25Z app[e78432edcd9248] syd [info]01:39:25.236 [error] Invocation processing failed: %Ash.Error.Invalid{bread_crumbs: ["Error returned from: Panic.Engine.Invocation.invoke"],  changeset: "#Changeset<>",  errors: [%Ash.Error.Changes.InvalidChanges{fields: nil, message: "Failed to parse JSON", validation: nil, value: nil, splode: Ash.Error, bread_crumbs: ["Error returned from: Panic.Engine.Invocation.invoke"], vars: [], path: [], stacktrace: #Splode.Stacktrace<>, class: :invalid}]}
```

What is the root cause, and what's the fix?

## Resolution

The root cause of the error was that the `handle_event("validate", ...)`
function in `PanicWeb.NetworkLive.TerminalComponent` was missing a clause to
handle the case when Phoenix LiveView sends validation events with only the
`_target` field (e.g., when a form field loses focus).

### Root Cause:

- Phoenix LiveView sends different parameter structures for validation events:
  - Full form submission: `%{"invocation" => params}`
  - Single field change/blur: `%{"_target" => ["invocation", "input"]}`
- The component only had a clause for the first case, causing a
  FunctionClauseError when the second case occurred

### Fix Applied:

Added a catch-all clause to handle validation events that don't include the full
form data:

```elixir
def handle_event("validate", _params, socket) do
  # Handle the case where only _target is sent (e.g., on field blur)
  # In this case, we don't need to validate as there are no new params
  {:noreply, socket}
end
```

The second error in the logs about "Failed to parse JSON" is unrelated to this
function clause error and appears to be a separate issue with model invocation
response parsing.

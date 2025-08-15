---
id: task-50
title: Convert RunnerStatusComponent to stateless function component
status: To Do
assignee: []
created_date: '2025-08-15 12:16'
labels: [refactoring, liveview, performance]
dependencies: []
---

## Description

Refactor `PanicWeb.NetworkLive.RunnerStatusComponent` from a stateful LiveComponent to a simpler stateless function component to reduce complexity and improve maintainability.

## Current Implementation

The component is currently a LiveComponent (`use PanicWeb, :live_component`) with:
- An `update/2` callback that derives status from invocations and fetches runner timing
- Internal state management for status derivation
- Direct calls to `NetworkRunner.get_runner_state/1` to fetch timing info

## Target Implementation

Convert to a stateless function component that:
- Receives all necessary data as assigns from the parent LiveView
- Returns only the rendered HTML without managing internal state
- Moves status derivation logic to the parent or a helper module

## Implementation Caveats & Considerations

### 1. WatcherSubscriber Integration
- The parent LiveView uses `WatcherSubscriber` to manage the invocation stream
- Currently, the component receives `invocations` from the stream and derives the current invocation
- **Challenge**: The function component would need the parent to extract and pass the current invocation explicitly

### 2. send_update Calls
- Multiple places call `send_update` to refresh the component:
  - On page load (`:update_runner_status` message)
  - On runner state changes (`"runner_state_changed"` broadcast)
  - When genesis invocation is received from TerminalComponent
- **Challenge**: Function components can't receive `send_update` calls; the parent would need to manage all state updates

### 3. NetworkRunner State Access
- The component directly calls `NetworkRunner.get_runner_state/1` in `fetch_runner_timing/1`
- **Challenge**: This would need to move to the parent LiveView, adding more state management there

### 4. Countdown Timer Hook
- The JavaScript hook `RunnerCountdown` depends on the component having a stable DOM ID
- **Challenge**: Ensure the function component maintains the same DOM structure and IDs

## Proposed Approach

1. **Move state derivation to parent LiveView**:
   - Add `current_invocation`, `runner_status`, and `next_invocation_time` to socket assigns
   - Update these in the parent's message handlers

2. **Create helper module** for status logic:
   ```elixir
   defmodule PanicWeb.NetworkLive.RunnerStatusHelper do
     def derive_status(genesis, current_invocation, lockout_seconds) do
       # Logic from derive_status_from_invocations/1
     end
     
     def format_status(status), do: # ...
     def format_run_age(genesis), do: # ...
     # etc.
   end
   ```

3. **Convert component to function**:
   ```elixir
   def runner_status(assigns) do
     ~H"""
     <div id={@id} class="mb-6">
       <!-- Current render template -->
     </div>
     """
   end
   ```

4. **Update parent LiveView**:
   - Replace `send_update` calls with direct assign updates
   - Fetch runner timing in parent handlers
   - Pass all derived state to the function component

## Benefits

- Simpler component architecture
- Easier to test (pure function)
- Better performance (no component process)
- Clearer data flow

## Drawbacks

- More complexity in parent LiveView
- Need to carefully manage state updates that previously triggered `send_update`
- Risk of regression if state derivation logic isn't properly moved

## Testing Requirements

- Verify countdown timer still works on page load
- Ensure status updates correctly on invocation changes
- Test runner state changes still reflect in UI
- Confirm no performance regression

## Notes

- Consider whether this refactoring provides enough value given the integration complexity
- The current LiveComponent approach might be justified given the component's interaction patterns
- Alternative: Keep as LiveComponent but simplify the update logic

---
id: task-53
title: network runner state management
status: To Do
assignee: []
created_date: "2025-08-18 06:54"
labels: []
dependencies: []
---

## Description

Look at the "State management" section in the
@lib/panic/engine/network_runner.ex moduledoc (and the code in that module). Are
there any simplifications which could be made to the state management logic?

The question arises because I'd like to make it easier for a liveview (when
loading/refreshing a view that is watching an existing running network) to find
out:

- whether the the network is :idle, :in_lockout, :invoking, :waiting to schedule
  the next invocation, or :failed (a special case of idle, where the last
  invocation failed)
- if the network is waiting, give the (absolute timestamp) time of the next
  invocation

The ultimate goal here is to make things simpler and easier to reason about;
some of the above states can probably be inferred from the rest of the GenServer
state (i.e. if genesis/current/next invocation are all nil then I guess it's
idle?).

One other goal is that the Ash notifications about invocations (i.e. what the
WatcherSubscriber module handles) should be able to infer as much as possible
about the NetworkRunner's state from each "new/updated invocation" pubsub
message. That might not be possible (e.g. an invocation completed message
doesn't say when the next one is scheduled) but again, if the state is
simplified then maybe this information can be obtained with minimal "staet
query" call messages back to the server.

Comment on the existence of a simpler state management solution, or reasons why
it is not possible. It's not necessary to draw a state diagram (of the network
state, plus all the genserver call messages) but do that if it's helpful.

## Solution: Switch to Rich Status

Simplify NetworkRunner state management by consolidating all state into a single rich status field that contains all relevant information for each operational state.

### Current State Structure (7 fields)

```elixir
%{
  network_id: integer,
  genesis_invocation: nil | %Invocation{},
  current_invocation: nil | %Invocation{},  
  watchers: list(),
  lockout_timer: nil | timer_ref,
  next_invocation: nil | %Invocation{},
  next_invocation_time: nil | DateTime
}
```

### Proposed Rich Status Structure (3 fields)

```elixir
%{
  network_id: integer,
  status: status_tuple(),  # One of 5 status variants
  active_timer: nil | timer_ref
}
```

Where status is one of:
- `{:idle}` - No active run
- `{:processing, invocation_id}` - Actively invoking a model
- `{:in_lockout, expires_at, genesis}` - In lockout period, rejecting new runs
- `{:waiting_next, next_at, current_invocation}` - Waiting to process next invocation (interruptible)
- `{:failed, last_invocation}` - Last invocation failed

### Key Behavioral Differences

- **In lockout**: New run attempts are REJECTED until lockout expires
- **Waiting next**: New run attempts CANCEL the current run and start fresh
- **Failed**: Ready to start a new run immediately

### Enhanced Broadcast Messages

Every `runner_state_changed` broadcast will include complete information:

```elixir
# For :in_lockout status
%{
  status: :in_lockout,
  network_id: network_id,
  lockout_expires_at: DateTime,
  seconds_remaining: integer,
  genesis_invocation: %Invocation{},
  can_start_run: false
}

# For :waiting_next status  
%{
  status: :waiting_next,
  network_id: network_id,
  next_invocation_at: DateTime,
  seconds_until_next: integer,
  current_invocation: %Invocation{},
  genesis_invocation: %Invocation{},
  can_start_run: true
}
```

LiveViews will have all needed information without additional queries.

### Implementation Benefits

1. **Single source of truth** - Status field contains everything needed
2. **Clean pattern matching** - State transitions via pattern matching on status tuples
3. **Atomic transitions** - State changes are single assignments
4. **Simpler testing** - Assert on one field instead of checking multiple
5. **Better maintainability** - Clear status type definition documents all states

### Timer Management Simplification

Consolidate all timer handling into a single `active_timer` field that gets set/cancelled on state transitions. Only one timer is ever active (either lockout countdown or next invocation delay).

### Implementation Steps

1. Add new `status` field to existing state
2. Update `determine_runner_status/1` to derive status from new field
3. Update `broadcast_runner_state/1` to send rich messages
4. Migrate all `handle_call` and `handle_info` clauses to pattern match on status
5. Remove old state fields once migration complete
6. Update tests to assert on status field

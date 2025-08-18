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

---
id: task-44
title: watcher audit
status: Done
assignee: []
created_date: "2025-08-15 05:19"
labels: []
dependencies: []
completed_date: "2025-08-15 06:51"
---

## Description

This project has several related modules for providing the "watcher"
functionality---which in essence allows any liveview to watch/listen for new
Invocations for a given Network. This is used for (amongst other things) having
live web-based displays that always show the most recent Invocation. The watcher
functionality also uses Phoenix Presence tracking to provide a view of the
number of "current watchers" (e.g. for a given Installation).

Examine the codebase and perform an audit of:

- the architecture of the watcher functionality (is it DRY, etc.)
- the way that existing notification/presence tracking is used (e.g. the
  AshNotification "event streams", the use of Phoenix Presence, etc.)
- for the watchers (e.g. single/grid watchers) is the tracking of Invocation
  events as robust as possible? Or are there chances of missing events?

## Audit Findings

### Architecture Analysis

#### Strengths

1. **Well-centralised core logic**: The `WatcherSubscriber` module serves as a central orchestrator, providing an `on_mount` hook that handles all subscription management, presence tracking, and stream updates. This prevents code duplication across LiveViews.

2. **Clean separation of concerns**:
   - `WatcherSubscriber`: Core subscription and stream management
   - `Presence`: Viewer tracking
   - `NetworkRunner`: Event generation and broadcasting
   - `Installation`/`Config`: Display configuration
   - Individual LiveViews: UI presentation only

3. **Flexible display mode system**: The display tuple format (`{:grid, rows, cols}` and `{:single, offset, stride, show_invoking}`) is consistently used throughout the system, with clean conversion from Installation configs.

4. **Good use of LiveView patterns**: The `attach_hook` mechanism elegantly handles all invocation broadcasts without requiring boilerplate in individual LiveViews.

#### Areas for Improvement

1. **Display mode detection**: The `on_mount` hook mentions that display mode detection was problematic when done too early (before `live_action` is set). The current approach defers stream configuration to `handle_params`, which adds complexity.

2. **Configuration validation**: While Installation.Config has strong typing, there's no runtime validation that display modes are compatible with the network's model types (e.g., grid displays for image outputs).

3. **Test isolation challenges**: The module documentation notes that NetworkRunner GenServers persist in the registry across tests, requiring manual cleanup. This suggests the architecture could benefit from better test isolation mechanisms.

### Notification/Presence Tracking Analysis

#### Strengths

1. **Proper use of Ash pub_sub**: The Invocation resource correctly configures pub_sub to broadcast all updates on the "invocation:{network_id}" topic. This ensures no state changes are missed.

2. **Phoenix Presence integration**: Well-implemented presence tracking with comprehensive metadata (user info, display mode, installation context, join timestamp). The metadata updates when display modes change.

3. **Viewer-aware optimisations**: NetworkRunner only broadcasts lockout countdowns when viewers are present, reducing unnecessary network traffic.

4. **Multiple subscription channels**: The system properly handles both invocation events and installation updates, allowing dynamic network switching.

#### Areas for Improvement

1. **Presence update vs track**: The code uses both `track` and `update` operations, but there's no clear documentation about when `update` might fail if tracking wasn't established first.

2. **Presence cleanup**: While `untrack` is called when switching networks, there's no explicit error handling if untracking fails.

### Event Tracking Robustness Analysis

#### Strengths

1. **Run isolation**: The genesis invocation (sequence 0) system ensures clean run boundaries. Each run is identified by `run_number` (the genesis invocation's ID), preventing cross-run contamination.

2. **Mid-run join handling**: When a viewer joins mid-run, the system fetches the genesis invocation from the database to establish proper context. This ensures late joiners see the correct run.

3. **Archive URL filtering**: The system filters out invocations with Tigris storage URLs to prevent display of archived content.

4. **State-based filtering**: The `show_invoking` flag provides control over whether in-progress invocations are displayed, preventing constant UI updates during processing.

5. **Comprehensive test coverage**: The test suite includes property-based testing for stride/offset logic and covers edge cases like mid-run joins and different run scenarios.

#### Potential Issues and Recommendations

1. **Race condition in genesis fetching**: When fetching genesis invocations for mid-run joins, there's no retry mechanism if the fetch fails. This could leave viewers in an inconsistent state.
   - **Recommendation**: Add retry logic with exponential backoff for genesis fetching.

2. **No deduplication of events**: If the same invocation update is broadcast multiple times (e.g., due to retries), the system will process it multiple times.
   - **Recommendation**: Track the last processed invocation state to avoid duplicate updates.

3. **Stream reset on network switch**: When installations switch networks, the stream is reset but there's no guarantee that the new network's genesis will be available immediately.
   - **Recommendation**: Preload the new network's genesis invocation when switching.

4. **No explicit error recovery**: If `stream_insert` fails, there's no error handling or retry mechanism.
   - **Recommendation**: Add error boundaries and recovery mechanisms for stream operations.

5. **Lockout timer edge cases**: The lockout timer continues even if all viewers disconnect. While not critical, this wastes resources.
   - **Recommendation**: Cancel lockout timer when viewer count reaches zero.

6. **Missing event ordering guarantees**: While invocations are processed in sequence, there's no explicit handling of out-of-order broadcasts.
   - **Recommendation**: Add sequence number validation to ensure events are processed in order.

### Overall Assessment

**Score: B+**

The watcher architecture is well-designed and generally robust, with good separation of concerns and proper use of Phoenix/Ash patterns. The main areas for improvement are:

1. **Error recovery**: Add more robust error handling and retry mechanisms
2. **Event deduplication**: Prevent duplicate processing of the same event
3. **Test isolation**: Improve test cleanup strategies
4. **Documentation**: Add more inline documentation about edge cases and failure modes

The system is production-ready but would benefit from these enhancements to move from "good" to "excellent" reliability.

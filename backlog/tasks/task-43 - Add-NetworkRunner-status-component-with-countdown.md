# Task: Add NetworkRunner status component with countdown

**Description:** Add a component to show NetworkRunner state (idle/processing/waiting) with client-side countdown timer when there's a delay before next invocation. Display below Control Panel section with run age and sequence number.

**Status:** Done

**Created:** 2025-01-15

## Requirements

### Visual Requirements
- Position: Below "Control Panel" section on Network Show page
- Display format for countdown: "Next invocation in N seconds"
- Status labels:
  - "Idle" - no run active
  - "Processing" - currently invoking
  - "Waiting" - countdown to next invocation
  - "In lockout" - during lockout period
  - "Failed" - if last invocation failed (only if reliable to detect)

### Information to Display
- Current status (as above)
- Time since genesis (run age)
- Current sequence number
- Countdown timer when waiting for next invocation

### Technical Requirements
- Use Phoenix LiveView Colocated JS hooks for client-side countdown
- Subscribe to NetworkRunner state changes
- Handle both inter-invocation delays and lockout periods
- Graceful handling if NetworkRunner process not running

## Implementation Plan

1. **Modify NetworkRunner to broadcast state changes**
   - Add broadcasts for state transitions
   - Include next_invocation_time in broadcasts
   - Include failure state if detectable

2. **Create RunnerStatusComponent LiveComponent**
   - Display current state with appropriate styling
   - Show run age and sequence number
   - Include countdown when applicable

3. **Create JavaScript Hook for countdown**
   - Client-side second-by-second countdown
   - Initialize with server-provided target time
   - Clean up on unmount

4. **Integrate into Network Show page**
   - Add component below Control Panel section
   - Subscribe to NetworkRunner broadcasts
   - Pass state to component

## Notes

- Component should handle missing NetworkRunner gracefully (show as "Idle")
- Countdown should stay in sync with server state
- Consider performance of second-by-second updates

## Implementation Summary

Completed implementation includes:

1. **NetworkRunner Updates**:
   - Added `broadcast_runner_state/1` function to broadcast state changes
   - Added `determine_runner_status/1` to determine current status
   - Added `get_runner_state/1` public function to fetch current state
   - Broadcasts state on all major transitions (start, stop, delay, error)

2. **RunnerStatusComponent LiveComponent**:
   - Displays status with color-coded badges
   - Shows run age in human-readable format (e.g., "2m 15s", "1h 30m")
   - Shows current sequence number
   - Includes countdown when waiting for next invocation
   - Detects failed state when current invocation has failed

3. **JavaScript Countdown Hook**:
   - Client-side countdown timer using setInterval
   - Updates every second
   - Handles target time updates
   - Cleans up timer on unmount

4. **Integration**:
   - Added component to Network Show page below Control Panel
   - Subscribes to runner_state_changed broadcasts
   - Handles both initial load and live updates
   - Gracefully handles missing NetworkRunner (shows as Idle)

## Bug Fixes

Fixed test failures by updating broadcast message handlers:
- `WatcherSubscriber`: Added filtering for `runner_state_changed` and `lockout_countdown` events
- `AdminLive`: Added explicit handler for `runner_state_changed` to skip it
- These modules were expecting all invocation broadcasts to have `payload.data` with invocation data
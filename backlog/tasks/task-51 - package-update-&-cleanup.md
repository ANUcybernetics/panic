---
id: task-51
title: package update & cleanup
status: Done
assignee: []
created_date: '2025-08-16 11:36'
updated_date: '2026-10-15 00:54'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
- update to phoenix 1.8 and liveview 1.1 (includes a usage rules file)
- can we remove oban now?

remember to use igniter.upgrade (not plain deps.update)
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Phoenix 1.8, LiveView 1.2, upgraded via igniter.upgrade. Oban came back deliberately (Lite engine) to schedule invocations and deliver signal listeners.
<!-- SECTION:FINAL_SUMMARY:END -->

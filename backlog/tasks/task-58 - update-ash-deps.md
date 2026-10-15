---
id: TASK-58
title: update ash deps
status: Done
assignee: []
created_date: '2025-10-19 21:21'
updated_date: '2026-10-15 00:54'
labels: []
dependencies: []
---

Something went wrong with a previous "ash\_\*" dep update (auth, phoenix, not
sure exaclty what the right one is) so that an `mix igniter.upgrade` doesn't
work.

Potential solutions are:

- look through the relevant changelogs and perform any required changes manually
- remove the files that conflict (and cause the igniter update task to fail),
  delete them, then re-do the upgrade task (checking on the difference between
  the old and new versions)

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ash 3.36, ash_sqlite 0.2.19, ash_phoenix 2.3.25, ash_authentication 4.15 (2377a172, 98960e72).
<!-- SECTION:FINAL_SUMMARY:END -->

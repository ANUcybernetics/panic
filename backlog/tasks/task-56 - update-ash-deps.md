---
id: task-56
title: update ash deps
status: To Do
assignee: []
created_date: "2025-10-19 21:21"
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

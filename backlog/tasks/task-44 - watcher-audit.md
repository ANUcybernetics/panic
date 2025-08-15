---
id: task-44
title: watcher audit
status: To Do
assignee: []
created_date: "2025-08-15 05:19"
labels: []
dependencies: []
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

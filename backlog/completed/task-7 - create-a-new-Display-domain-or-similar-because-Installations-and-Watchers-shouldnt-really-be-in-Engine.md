---
id: task-7
title: >-
  create a new 'Display' domain or similar (because Installations and Watchers
  shouldn't really be in 'Engine')
status: Done
assignee: []
created_date: "2025-07-08"
labels:
  - refactoring
  - architecture
dependencies: []
---

## Description

The `Panic.Engine` Ash domain is a bit overloaded. Conceptually it'd be best to
have that just include things to do with the core "runner" loop of the app.
Then, there could be a new `Panic.Watcher` domain which included all the stuff
to do with "invocation watching". This will also require renaming some modules
(e.g. `PanicWeb.WatcherSubscriber`) because that would be the name of the
domain, and all the specific modules would need new names.

I'm not set on this idea just yet, but it's important to think hard about the
pros & cons, with the ultimate goal being a simpler, clearer architecture and
more maintanable app.

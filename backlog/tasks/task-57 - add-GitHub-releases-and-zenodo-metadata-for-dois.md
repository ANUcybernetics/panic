---
id: task-57
title: add GitHub releases and zenodo metadata for dois
status: Done
assignee: []
created_date: "2025-10-21 22:24"
completed_date: "2025-10-22"
labels: []
dependencies: []
---

I'd like to add github releases to this project (according to the standard
elixir phoenix conventions). The primary purpose is to use the Zenodo GitHub
integration to add a DoI for PANIC!

I'd like to:

- identify the key version milestones
  - v0 is the original prototype
  - v1 is the version deployed for Australian Cybernetic in Nov 2022
  - v2 is the Birch install (switch to ash, sqlite)

However, while I have been good at versioning this project through git I haven't
been good at keeping the version info (e.g. in mix.exs) up to date. There may
even be an off-by-one error in the version number listing above.

First, conduct a thorough investigation (via the git history) and identify the
commits which represent key "major version" releases.

After that we'll do some git surgery to insert the correct metadata and tags and
make the (retrospective) GitHub releases. But first, we need to identify the
commits.

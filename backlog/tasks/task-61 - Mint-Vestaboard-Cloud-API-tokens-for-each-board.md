---
id: TASK-61
title: Mint Vestaboard Cloud API tokens for each board
status: To Do
assignee: []
created_date: '2026-10-20 09:33'
labels:
  - vestaboard
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PANIC! now sends to Vestaboards through the Cloud API (cloud.vestaboard.com, X-Vestaboard-Token header), so the stored legacy Read/Write keys may no longer work. Vestaboard has no API for minting tokens, so create one per board by hand: web.vestaboard.com API tab (or mobile app Settings → Advanced Settings) → Create New Token, write permission only, named after the board. Tokens are shown once.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 each of panic_1 to panic_4 has a write-only Cloud API token
- [ ] #2 the four tokens are saved in the PANIC! admin credentials form in production
- [ ] #3 a run in production updates every Vestaboard it targets
<!-- AC:END -->

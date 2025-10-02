---
id: task-48
title: switch Swoosh from brevo to postmark
status: Done
assignee: []
created_date: "2025-08-15 10:33"
labels: []
dependencies: []
---

## Description

All throughout the codebase, replace the usage of the Brevo email service with
Postmark.

For reference, there's another project on this machine which has a working
postmark setup: /Users/ben/Documents/edex/cozzieloops

## Completed Changes

Successfully migrated from Brevo to Postmark email service:

1. **Updated `/config/runtime.exs`:**
   - Changed alias from `Swoosh.Adapters.Brevo` to `Swoosh.Adapters.Postmark`
   - Updated `Panic.Mailer` configuration to use Postmark adapter
   - Updated `TowerEmail.Mailer` configuration to use Postmark adapter
   - Changed environment variable from `BREVO_API_KEY` to `POSTMARK_API_KEY`
   - Added `message_stream: "outbound"` configuration
   - Added `from_email` configuration with default "panic@benswift.me"

2. **Verified:**
   - Project compiles successfully
   - All tests pass (including TowerEmail tests)
   - No other references to Brevo found in the codebase

## Environment Variables Required

For production deployment, you'll need to set:
- `POSTMARK_API_KEY` - Your Postmark API key
- `FROM_EMAIL` (optional) - Override the default from email (defaults to "panic@benswift.me")

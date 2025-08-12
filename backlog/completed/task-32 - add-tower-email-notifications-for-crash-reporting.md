---
id: task-32
title: add tower email notifications for crash reporting
status: Done
assignee: []
created_date: "2025-07-17"
labels: []
dependencies: []
---

## Description

The Brevo Swoosh adapter is set up (I think) but I'm not sure if the TowerEmail
resporting is set up correctly. I've tried calling `trigger_test_crash` from
@lib/panic.ex in production, but it didn't seem to send any emails.

## Resolution

Fixed Tower and TowerEmail configuration issues:

1. **Fixed Tower configuration format** - Changed from nested list `[[TowerEmail, [...]]]` to tuple `{TowerEmail, [...]}`
2. **Added missing environment configuration** - TowerEmail requires `:environment` config
3. **Configured TowerEmail.Mailer properly** - Set up TowerEmail.Mailer to use Local adapter in dev and Brevo in production
4. **Fixed Panic.Mailer configuration** - Ensured Panic.Mailer uses Local adapter in dev (was overridden by secrets.exs)

### Configuration changes:

- `config/config.exs`: Proper Tower and TowerEmail configuration
- `config/dev.exs`: Override Panic.Mailer to use Local adapter after importing secrets.exs
- `config/runtime.exs`: Configure TowerEmail.Mailer with Brevo for production

### Testing functions:
- `Panic.trigger_test_crash/0` - Synchronous crash (caught by IEx)
- `Panic.trigger_async_test_crash/0` - Async crash in Task (properly caught by Tower)

Tower is now properly configured to send email notifications on crashes in both development and production environments.
---
id: task-32
title: add tower email notifications for crash reporting
status: To Do
assignee: []
created_date: "2025-07-17"
labels: []
dependencies: []
---

## Description

The Brevo Swoosh adapter is set up (I think) but I'm not sure if the TowerEmail
resporting is set up correctly. I've tried calling `trigger_test_crash` from
@lib/panic.ex in production, but it didn't seem to send any emails.

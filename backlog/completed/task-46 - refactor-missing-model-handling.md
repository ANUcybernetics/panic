---
id: task-46
title: refactor missing model handling
status: Done
assignee: []
created_date: '2025-08-15 06:38'
labels: []
dependencies: ["task-45"]
---

## Description

Simplify the handling of deleted models by centralizing logic instead of defensive code everywhere

## Problem

The current implementation (from task-45) added defensive code in many places to handle missing models. This has created unnecessary complexity throughout the codebase with checks scattered everywhere.

## Proposed Solution

Implement a cleaner, more centralized approach:

1. **Keep Model.by_id/1** - Non-raising version for checking if models exist
2. **NetworkShow & ModelSelectComponent** - Keep validation/fixing behavior for broken networks
3. **Historical invocation viewing** - Allow viewing old invocations even with deleted models (show "Unknown Model" placeholder)
4. **Network execution pages** - Redirect to NetworkShow with error flash when trying to run broken networks
5. **Simplify validation** - Keep validation logic but make it cleaner

## Implementation Plan

### Phase 1: Establish Core Helpers
- Create a helper to check if a network has missing models
- Create a helper to handle missing model redirects

### Phase 2: Simplify Display Components
- **Static display pages** - Show invocations with "Unknown Model" for missing models (no redirect)
- **Admin page** - Show invocations with missing model indicator (no redirect)
- **Components** - Simplified display with fallback for missing models

### Phase 3: Handle Execution Paths
- **Terminal pages** - Check for missing models, redirect to NetworkShow if broken
- **NetworkRunner** - Keep minimal safety check for archiving
- **InvokeModel** - Keep error handling for missing models

### Phase 4: Clean Up
- Remove excessive defensive code
- Consolidate validation logic
- Update tests

## Success Criteria
- No crashes when models are deleted
- Users can view historical invocations
- Users are guided to fix broken networks in one place
- Code is cleaner with centralized logic

## Implementation Summary

Successfully refactored the missing model handling to use a cleaner, more centralized approach:

1. **Created NetworkHelpers module** - Central place for network validation logic and placeholder generation
2. **Simplified display components** - Use placeholder models for missing ones, allowing historical viewing
3. **Added redirect logic** - Terminal pages redirect to NetworkShow when network is broken
4. **Kept essential safety checks** - ModelSelectComponent validation and InvokeModel error handling remain
5. **Removed excessive defensive code** - Eliminated scattered nil checks throughout the codebase

The solution is much cleaner than the initial approach, with logic centralized in one helper module rather than defensive code scattered everywhere. Users can still view historical invocations but are redirected to fix broken networks when trying to run them.

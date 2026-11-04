---
id: TASK-62
title: Backfill image placeholders and upload metadata for archived outputs
status: To Do
assignee: []
created_date: '2026-11-04T03:23:00Z'
labels:
  - archiver
  - run-images
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The run images page (PanicWeb.NetworkLive.RunImages, /networks/:network_id/runs/:run_number) shows each image's placeholder, blurred, while the full image loads, so swiping through a run on cell data never shows a blank screen. The archiver only started making placeholders (Panic.Engine.Archiver.placeholder/1, stored in Invocation.placeholder) in commit e25883b5, so every image archived before then shows a plain black screen until it loads.

The same commit made uploads set Content-Type and Cache-Control: public, max-age=31536000, immutable. Objects already in the panic-invocation-outputs Tigris bucket are still served as binary/octet-stream with no Cache-Control, so browsers revalidate them. S3 CopyObject onto the same key with MetadataDirective REPLACE fixes them in place without changing their URLs. Both fixes visit every archived object, so do them in one pass.

The Tigris keys in local dev are not valid (InvalidAccessKeyId), so this needs prod's credentials, e.g. run on the Fly machine. Model calls aren't involved, but prod runs share the bucket: don't touch objects that aren't archived invocation outputs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every completed invocation whose output is an archived WebP on fly.storage.tigris.dev has a non-nil placeholder
- [ ] #2 Archived .webp objects serve Content-Type image/webp and archived .mp3 objects serve audio/mpeg
- [ ] #3 Every archived object serves Cache-Control: public, max-age=31536000, immutable
- [ ] #4 Archived URLs are unchanged, so existing invocation inputs and outputs still resolve
- [ ] #5 The backfill can be re-run safely, skipping work already done
<!-- AC:END -->

---
id: TASK-62
title: Backfill image placeholders and upload metadata for archived outputs
status: Done
assignee: []
created_date: '2026-11-04T03:23:00Z'
updated_date: '2026-11-04T06:17:00Z'
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
- [x] #1 Every completed invocation whose output is an archived WebP on fly.storage.tigris.dev has a non-nil placeholder
- [x] #2 Archived .webp objects serve Content-Type image/webp and archived .mp3 objects serve audio/mpeg
- [x] #3 Every archived object serves Cache-Control: public, max-age=31536000, immutable
- [x] #4 Archived URLs are unchanged, so existing invocation inputs and outputs still resolve
- [x] #5 The backfill can be re-run safely, skipping work already done
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Backfilled on prod on 2026-11-04 with a one-off script run on the Fly machine (not committed): CopyObject onto the same key with MetadataDirective REPLACE for headers, then Archiver.placeholder/1 for each WebP. 24,795 objects; a second pass reported every object already done.

Exceptions to ACs 1-3: 239 objects (138 .webp, 101 .webm) for invocations 886-1374, from 10 runs on 2024-10-10 and 11, are 404 in the bucket, so they have neither headers nor placeholders. Every .webm output is among them. All .mp3 objects and every other .webp are fixed. ETags and URLs were unchanged.
<!-- SECTION:NOTES:END -->

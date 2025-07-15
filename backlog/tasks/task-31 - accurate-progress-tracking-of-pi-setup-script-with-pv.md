---
id: task-31
title: accurate progress tracking of pi setup script with pv
status: In Progress
assignee: []
created_date: "2025-07-15"
labels: []
dependencies: []
---

## Description

For @rpi/pi-setup.sh I'd like to find a way to get the size of the uncompressed
image (so that pv can accurately report the progress and ETA). The issue is that
`xz -l` can't give the uncompressed size in bytes, it always seems to format it
in a human-readable format.

I have noticed that there's a python package (including cli) called
[humanfriendly](https://pypi.org/project/humanfriendly/) which can be used to
convert file sizes to human-readable formats. I've installed that with
`uv tool install humanfriendly`, because all the python tools on this system
must be managed by uv. However, on trying to run it I get an error.

Ultimately I don't care how it's done, and I'm open to installing new tools, but
I also don't want to overcomplicate things.

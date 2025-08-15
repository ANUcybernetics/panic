---
id: task-8
title: >-
  add an image->image flux model (and perhaps a way to still kick it off with
  text)
status: To Do
assignee: []
created_date: "2025-07-08"
labels:
  - feature
  - ai-models
dependencies: []
---

## Description

I think the way to do this is to have a two-model pipeline:

- the first model: _if_ it's the genesis, just generate an image with
  <https://replicate.com/black-forest-labs/flux-kontext-pro>, but if not then
  receive the input as an image URL and feed it back in to the same model (with
  the URL in the `input_image` field and the prompt being "replicate this image
  exactly, pixel-for-pixel")

- the second model: essentially just a image->text passthrough (necessary
  because the initial prompt is text, and so "validate network I/O" won't allow
  just a single image->image as a network)

This is a _bit_ messy in that these models will really have to work together,
breaking the "supports any configuration of models" behaviour. But it's a nicer
(and easier) fix than having to re-architect the whole network concept to
support multiple inputs/outputs.

## New models to add

These are two image-to-image models which could form the basis of the above
pipeline

- https://replicate.com/black-forest-labs/flux-kontext-dev/llms.txt
- https://replicate.com/bytedance/seededit-3.0/llms.txt

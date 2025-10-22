---
id: task-8
title: add an image->image flux model (which still validates and starts with text)
status: Done
assignee: []
created_date: '2025-07-08'
updated_date: '2025-10-17 23:53'
labels:
  - feature
  - ai-models
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Panic needs to support networks with "image editing" models which (conceptually)
at least take an initial text input and generate an image, but then repeatedly
process the image with the text instruction "reproduce this image exactly,
pixel-for-pixel". The challenge is that Panic doesn't currently support
multiple-input models, and both input and output have to have a single, fixed
modality (e.g. `:text` or `:image`).

I think the way to do it is to have a two-model pipeline:

- the first model: _if_ it's the genesis, just generate an image based on the
  input text prompt, but if not then receive the input as an image URL and feed
  it back in to the same model (with the URL in the `input_image` field and the
  prompt being "replicate this image exactly, pixel-for-pixel")

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

They could be called e.g. "Image Reproducer I (flux)" and "Image Reproducer II
(flux)" (or "seedit" for the "seededit" model).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added five new models to `lib/panic/model.ex`:

1. **Image Reproducer I (Flux)** (`image-reproducer-i-flux`):

   - Uses black-forest-labs/flux-kontext-dev for image reproduction
   - Input: text, Output: image
   - Detects if input is URL (image reproduction) or text (genesis)
   - For genesis: calls flux-schnell model to generate initial image
   - For reproduction: uses "reproduce this image exactly, pixel-for-pixel"
     prompt

2. **Image Reproducer II (Flux)** (`image-reproducer-ii-flux`):

   - Passthrough model to complete the network cycle
   - Input: image, Output: text
   - Simply returns the image URL as text

3. **Seedream 3** (`seedream-3`):

   - Standalone text-to-image model from ByteDance
   - Uses bytedance/seedream-3
   - High-quality image generation with configurable aspect ratio

4. **Image Reproducer I (Seed)** (`image-reproducer-i-seed`):

   - Uses bytedance/seededit-3.0 for image reproduction
   - For genesis: calls seedream-3 model to generate initial image
   - For reproduction: uses "reproduce this image exactly, pixel-for-pixel"
     prompt

5. **Image Reproducer II (Seed)** (`image-reproducer-ii-seed`):
   - Passthrough model for SeedEdit variant
   - Same behaviour as Flux passthrough

The models work together in a network:

- First model takes text input and generates or reproduces images
- Genesis: calls appropriate text-to-image model (flux-schnell or seedream-3)
- Reproduction: uses the image editing models with pixel-perfect prompt
- Second model passes through the image URL as text to complete the cycle
- Network validation passes since it starts with text and has valid I/O
  connections
- All messiness is self-contained within the invoke functions
<!-- SECTION:NOTES:END -->

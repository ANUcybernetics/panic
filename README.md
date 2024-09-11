# Panic!

## **P**layground **A**i **N**etwork for **I**nteractive **C**reativity

The rise of cloud AI platforms like OpenAI and HuggingFace means that using
Creative AI models is no longer (necessarily) a toilsome struggle against
undocumented python code and CUDA version errors. Anyone with a credit card can
log in, input their text/image/audio, hit "run model", and see for the results.
This has led to a Cambrian explosion of AI art - good and bad - as new, diverse
voices probe the input manifolds of models like GPT-3 and DALL-E. The Creative
AI practitioner is therefore presented with the eternal Jurassic Park question:
just because we _can_ put our text/audio/images into these models have them
provide new text/audio/images in return, does it mean that we _should_?

At the Creative AI symposium we will demo new Creative AI app called **PANIC:
Playground Ai Network for Interactive Creativity**---probably through a talk,
but with plenty of examples and maybe even some live coding/demos. This web app
allows users to connect up arbitrary networks of Creative AI models to one
another. The app requires the "modality" of each connection to match up, for
example the text output of GPT-3 may be fed into the text input of a DALL-E
mini, or the audio output of a "musical style transfer" model to a "speech to
text" one. PANIC imposes no other restrictions about whether any particular
connection makes sense from a semantic perspective---the practitioner is free to
hook things up and see what behaviours the network manifests.

Along with generating interesting (and sometimes cooked) text/audio/image
outputs, the purpose of PANIC is to explore how different ways of connecting
these hosted Creative AI models---different network topologies---give rise to
different outputs. What are the fixed points of a given network of models? Where
are the "attractors" in the phase space of all possible inputs, and where are
the phase transitions? When there are closed loops in the network (an "AI
Ouroboros"), does the system settle into some sort of "steady state"? Do they
generate any interesting outputs which we may not have seen with just individual
prompting of a single model?

The general outline for our proposed talk/presentation is:

- introduction (with examples/demo) to Creative AI model platforms e.g. OpenAI,
  HuggingFace, AccompliceAI

- explanation & demo of the PANIC "create a network of AI models" interface

- set up different PANIC network topologies, seeing how different
  text/audio/image inputs are transformed as they are passed through different
  Creative AI networks (including "closed loop" topologies)

- discussion of emergent behaviours, recurring patterns, degenerate & edge
  cases, and what it all says about the nature of Creative AI model platforms in
  their current form

While PANIC is an experimental tool for creative "play", the accessibility of
these AI model platforms (cost, time, technical knowledge) means that their
inputs & outputs are being increasingly taken up in the flows of people &
culture which traverse our world---participating in both human and non-human
feedback loops. PANIC is a playground for leaning in to that connectivity to
better understand where that road leads.

Note to symposium organisers: PANIC doesn\'t exists in a robust, shareable form
just yet, but you have my (Ben\'s) word as a creative coder that it\'ll be
working and demoable by the symposium date ;)

## About the School of Cybernetics

At the School of Cybernetics we love thinking about the way that feedback loops
(and the connections between components in general) define the behaviour of the
systems in which we live, work and create. That interest sits behind the design
of PANIC as a tool for making (and breaking!) networks of hosted Creative AI
models, and in our preso we\'re happy to go into some of the cybernetic ideas
behind the design - or to focus on the app (and its inputs/outputs) itself -
happy to fit with whatever will make the most kickarse symposium for everyone.

## Development

It's a standard Phoenix (v1.7) and Phoenix LiveView (v0.18) app, so all those
guides should help you out.

Inside the codebase here's a (domain) glossary to help you figure out what's
going on:

- **model**: a particular AI model (e.g. _Stable Diffusion_, _GPT4o_)
- **platform**: model-hosting cloud platform (e.g.
  [Replicate](https://replicate.com), [OpenAI](https://openai.com))
- **network**: a specific network (i.e. cyclic graph) of models, designed so
  that the output of one is fed as input to the next
- **invocation**: a specific "inference" event for a single model; includes both
  the input (prompt) an the output (prediction) along with some other metadata
- **run**: a specific sequence of predictions starting from an initial prompt
  and following the models in a network

## Setup

We use [asdf](https://asdf-vm.com) for managing tool versions.

The file `.tool-version` tells asdf which versions we use.

Run `asdf install` to install those versions.

## SXSW blurb

PANIC is an interactive installation where **you** can play with feedback loops
of generative AI models hooked end-to-end. As well as generating intriguing
text, images and audio, PANIC explores how different ways of connecting these
models up can give rise to different patterns of outputs, emergent behaviours,
recurring patterns, and degenerate cases. Today, the low barrier to entry in
generative AI model platforms (in terms of cost, time, and knowledge) means that
more and more of us are using them. But just because we _can_ put our
text/images/audio into these models and have them provide new text/images/audio
in return, does it mean that we _should_?

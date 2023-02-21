# Panic!
## **P**layground **A**i **N**etwork for **I**nteractive **C**reativity

The rise of cloud AI platforms like OpenAI and HuggingFace means that using
Creative AI models is no longer (necessarily) a toilsome struggle against
undocumented python code and CUDA version errors. Anyone with a credit card can
log in, input their text/image/audio, hit "run model", and see for the results.
This has led to a Cambrian explosion of AI art - good and bad - as new, diverse
voices probe the input manifolds of models like GPT-3 and DALL-E. The Creative
AI practitioner is therefore presented with the eternal Jurassic Park question:
just because we *can* put our text/audio/images into these models have them
provide new text/audio/images in return, does it mean that we *should*?

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

-   introduction (with examples/demo) to Creative AI model platforms e.g.
    OpenAI, HuggingFace, AccompliceAI

-   explanation & demo of the PANIC "create a network of AI models" interface

-   set up different PANIC network topologies, seeing how different
    text/audio/image inputs are transformed as they are passed through different
    Creative AI networks (including "closed loop" topologies)

-   discussion of emergent behaviours, recurring patterns, degenerate & edge
    cases, and what it all says about the nature of Creative AI model platforms
    in their current form

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

- **model**: a particular AI model (e.g. _Stable Diffusion_, _GPT3 Davinci
  instruct_)
- **platform**: model-hosting cloud platform (e.g.
  [Replicate](https://asdf-vm.com), [OpenAI](https://openai.com))
- **network**: a specific network (i.e. cyclic graph) of models, designed so
  that the output of one is fed as input to the next
- **prediction**: a specific "inference" run for a single model; includes both
  the input (prompt) an the output (prediction) along with some other metadata
- **run**: a specific cycle of predictions starting from an initial prompt and
  following the models in a network (may or may not converge, depending on
  whether convergence testing is happening)

## Setup

We use [asdf](https://asdf-vm.com) for managing tool versions.

The file `.tool-version` tells asdf which versions we use.

Run `asdf install` to install those versions.

### Other Setup notes

```
mix phx.gen.context Models Run runs platform:enum:replicate:huggingface:openai model_name:string input:string output:string metadata:map
mix petal.gen.live Networks Network networks owner_id:references:users name:string models:array:integer loop:boolean
``````

## TODO

- instead of a table, use a flex container (with that cool forwards-bacwards
  flow direction thing) for the network models
- in append_model_widget, disable all the buttons for models which don't have
  the right input type
- add rolling cookie/URL param to QR code
- use (only) a form to manage the models in the network (create/edit network)
- add metadata to prediction
- port vestaboards code, add (as array) to prediction model
- add "slow down over time" logic to runs
- port view code
- check that access control works for the network & prediction
- port panic v2 code to the form components, including passing in assigns
- maybe use cast_assoc wherever it makes sense, e.g. API tokens?
- can probably simplify some of the get api token/get network code by just using
  the assoc on a %User{} (can still do it inside context module)
- add `has_many :networks, Panic.Networks.Network` to user
- rather than API token names being free strings, hardcode the specific ones we
  need, and change the API token /new page to list them all (and show green/red
  for which ones we have, and maybe even hit an endpoint to verify?)
- add network permalinks (look in the history - there's some deleted `router.ex`
  code in there)
- add models:
  - oblique strategies follower (GPT-3 powered)
  - https://replicate.com/cloneofsimo/lora
  - https://replicate.com/pharmapsychotic/clip-interrogator
- add model links to info maps

## Licence

(c) Ben Swift

MIT

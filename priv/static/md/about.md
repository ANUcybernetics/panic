# PANIC!: **P**layground **A**i **N**etwork for **I**nteractive **C**reativity

_PANIC!_ is an interactive installation where **you** can play with feedback
loops of generative AI (GenAI) models hooked up end-to-end. As well as
generating intriguing text, images and audio, PANIC! explores how different ways
of connecting these models up can give rise to different patterns of outputs,
emergent behaviours, recurring patterns, and degenerate cases. Today, the low
barrier to entry in GenAI model platforms (in terms of cost, time, and
knowledge) means that more and more of us are using them. But just because we
_can_ put our text/images/audio into these models and have them provide new
text/images/audio in return, does it mean that we _should_?

## SXSW 2024 instructions

If you've visited us at the SXSW Sydney Expo, welcome :) Panic is an interactive
installation, and we invite you to give it a try:

1. type something (anything!) on the keyboard
2. hit `Enter` & get ready to PANIC!
3. keep watching to see the initial output, then the subsequent outputs
4. what questions does this raise about feedback loops in GenAI-augmented
   systems?

## Techy stuff

Panic is the work of [Dr. Ben Swift](https://benswift.me) as part of his job at
the [ANU School of Cybernetics](https://cybernetics.anu.edu.au). The core
"engine" is an ([Ash](https://hexdocs.pm/ash/) +
[Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/))
[Elixir](https://elixir-lang.org) app, and it talks to various different hosted
GenAI platforms (e.g. [Replicate](https://replicate.com)) to run GenAI models
created by OpenAI, Anthropic, Meta, Amazon, Google, Microsoft and more. The
outputs of these models (text, images and audio) are displayed live, in
real-time, for viewers on screens anywhere in the world.

## PANIC! Research Questions

At the School of Cybernetics we love thinking about the way that feedback loops
(and the the connections between things) define the behaviour of the systems in
which we live, work and create. That interest sits behind the design of PANIC!
as a tool for making (and breaking!) networks of hosted generative AI models.

Anyone who's played with (or watched others play with) PANIC! has probably had
one of these questions cross their mind at some point.

One goal in building PANIC is to provide answers to these questions which are
both quantifiable and satisfying (i.e. it feels like they represent deeper
truths about the process).

**Maybe you've got some ideas about answers**? Chat to the friendly folks at the
PANIC! booth and let us know.

### how did it get _here_ from _that_ initial prompt?

- was it predictable that it would end up here?
- how sensitive is it to the input, i.e. would it still have ended up here with
  a _slightly_ different prompt?
- how sensitive is it to the random seed(s) of the models?

### is it stuck?

- the text/images it's generating now seem to be "semantically stable"; will it
  ever move on to a different thing?
- can we predict in advance which initial prompts lead to a "stuck" trajectory?

### has it done this before?

- how similar is this run's trajectory to previous runs?
- what determines whether they'll be similar? the initial prompt, or something
  else?

### which models have the biggest impact on what happens?

- do certain GenAI models dominate the trajectory? or is it an emergent property
  of the interactions between all models in the network?

## Contact

If you'd like to know more about PANIC!, contact Ben at
[ben.swift@anu.edu.au](mailto:ben.swift@anu.edu.au). If you'd like to keep
up-to-date about the School of Cybernetics, you can
[sign up for the mailing list](https://cybernetics.anu.edu.au/#subscribe-to-our-mailing-list-1).

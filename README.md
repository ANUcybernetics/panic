# PANIC!: **P**layground **A**i **N**etwork for **I**nteractive **C**reativity

_PANIC!_ is an interactive installation where **you** can play with feedback
loops of generative AI models hooked end-to-end. As well as generating
intriguing text, images and audio, PANIC explores how different ways of
connecting these models up can give rise to different patterns of outputs,
emergent behaviours, recurring patterns, and degenerate cases. Today, the low
barrier to entry in generative AI model platforms (in terms of cost, time, and
knowledge) means that more and more of us are using them. But just because we
_can_ put our text/images/audio into these models and have them provide new
text/images/audio in return, does it mean that we _should_?

## Development

It's a standard [AshPhoenix](https://hexdocs.pm/ash_phoenix/) and LiveView app,
so all those guides should help you out.

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

## About the School of Cybernetics

At the School of Cybernetics we love thinking about the way that feedback loops
(and the connections between components in general) define the behaviour of the
systems in which we live, work and create. That interest sits behind the design
of PANIC as a tool for making (and breaking!) networks of hosted Creative AI
models, and in our preso we're happy to go into some of the cybernetic ideas
behind the design - or to focus on the app (and its inputs/outputs) itself -
happy to fit with whatever will make the most kickarse symposium for everyone.

## Author

[Ben Swift](https://github.com/benswift)

## Licence

[MIT](https://opensource.org/licenses/MIT)

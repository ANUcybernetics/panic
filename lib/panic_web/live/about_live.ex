defmodule PanicWeb.AboutLive do
  @moduledoc false
  use PanicWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "About PANIC!")}
  end

  def render(assigns) do
    ~H"""
    <div class="prose prose-purple">
      <h1>
        PANIC!: <strong>P</strong>layground <strong>A</strong>i <strong>N</strong>etwork for <strong>I</strong>nteractive <strong>C</strong>reativity
      </h1>

      <p>
        <em>PANIC!</em>
        is an interactive installation where <strong>you</strong>
        can play with feedback
        loops of generative AI (GenAI) models hooked up end-to-end. As well as
        generating intriguing text, images and audio, PANIC! explores how different ways
        of connecting these models up can give rise to different patterns of outputs,
        emergent behaviours, recurring patterns, and degenerate cases. Today, the low
        barrier to entry in GenAI model platforms (in terms of cost, time, and
        knowledge) means that more and more of us are using them. But just because we <em>can</em>
        put our text/images/audio into these models and have them provide new
        text/images/audio in return, does it mean that we <em>should</em>?
      </p>

      <h2>Instructions</h2>

      <p>Panic is an interactive installation, and we invite you to give it a try:</p>

      <ol>
        <li>type something (anything!) on the keyboard</li>
        <li>hit <code>Enter</code> & get ready to PANIC!</li>
        <li>keep watching to see the initial output, then the subsequent outputs</li>
        <li>what questions does this raise about feedback loops in GenAI-augmented systems?</li>
      </ol>

      <h2>Techy stuff</h2>

      <p>
        Panic is the work of <a href="https://benswift.me">Dr. Ben Swift</a>
        as part of his job at
        the <a href="https://cybernetics.anu.edu.au">ANU School of Cybernetics</a>. The core
        "engine" is an (<a href="https://hexdocs.pm/ash/">Ash</a> + <a href="https://hexdocs.pm/phoenix_live_view/">Phoenix LiveView</a>)
        <a href="https://elixir-lang.org">Elixir</a>
        app, and it talks to various different hosted
        GenAI platforms (e.g. <a href="https://replicate.com">Replicate</a>) to run GenAI models
        created by OpenAI, Anthropic, Meta, Amazon, Google, Microsoft and more. The
        outputs of these models (text, images and audio) are displayed live, in
        real-time, for viewers on screens anywhere in the world.
      </p>

      <h2>PANIC! Research Questions</h2>

      <p>At the School of Cybernetics we love thinking about the way that feedback loops
        (and the the connections between things) define the behaviour of the systems in
        which we live, work and create. That interest sits behind the design of PANIC!
        as a tool for making (and breaking!) networks of hosted generative AI models.</p>

      <p>Anyone who's played with (or watched others play with) PANIC! has probably had
        one of these questions cross their mind at some point.</p>

      <p>One goal in building PANIC is to provide answers to these questions which are
        both quantifiable and satisfying (i.e. it feels like they represent deeper
        truths about the process).</p>

      <p><strong>Maybe you've got some ideas about answers</strong>? Chat to the friendly folks at the
        PANIC! booth and let us know.</p>

      <h3>how did it get <em>here</em> from <em>that</em> initial prompt?</h3>

      <ul>
        <li>was it predictable that it would end up here?</li>
        <li>how sensitive is it to the input, i.e. would it still have ended up here with
          a <em>slightly</em> different prompt?</li>
        <li>how sensitive is it to the random seed(s) of the models?</li>
      </ul>

      <h3>is it stuck?</h3>

      <ul>
        <li>the text/images it's generating now seem to be "semantically stable"; will it
          ever move on to a different thing?</li>
        <li>can we predict in advance which initial prompts lead to a "stuck" trajectory?</li>
      </ul>

      <h3>has it done this before?</h3>

      <ul>
        <li>how similar is this run's trajectory to previous runs?</li>
        <li>what determines whether they'll be similar? the initial prompt, or something else?</li>
      </ul>

      <h3>which parts of the system have the biggest impact on what happens?</h3>

      <ul>
        <li>does a certain GenAI model "dominate" the behaviour of the network? or is the
          prompt more important? or the random seed? or is it an emergent property of
          the interactions between all models in the network?</li>
      </ul>

      <h2>Contact</h2>

      <p>
        If you'd like to know more about PANIC!, contact Ben at <a href="mailto:ben.swift@anu.edu.au">ben.swift@anu.edu.au</a>. If you'd like to keep
        up-to-date about the School of Cybernetics, you can <a href="https://cybernetics.anu.edu.au/#subscribe-to-our-mailing-list-1">sign up for the mailing list</a>.
      </p>
    </div>
    """
  end
end

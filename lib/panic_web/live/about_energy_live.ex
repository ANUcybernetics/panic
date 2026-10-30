defmodule PanicWeb.AboutEnergyLive do
  @moduledoc """
  How the energy estimates on the displays are made. Its figures restate
  `Panic.Engine.Footprint` and `PanicWeb.RunFormat`, so change them together.
  """
  use PanicWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "PANIC! energy estimates")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="prose prose-purple">
        <h1>How PANIC! estimates its energy use</h1>

        <p>
          The screens show a running estimate of the energy each run has used so far. None
          of the platforms report the energy their models use, so the figures are ballpark
          estimates, not measurements. For models we pay for by the second of GPU time, the
          estimate is that time × the GPU's rated power × how hard the model works it × 1.2
          for the data centre's cooling and other overheads. Image and music models keep
          the GPU busy, so they count at 0.7 of its rated power (<a href="https://epoch.ai/gradient-updates/how-much-energy-does-chatgpt-use">Epoch AI's</a>
          assumption for inference); language and speech models handling one request at a
          time mostly wait on memory and draw much less (<a href="https://arxiv.org/abs/2505.06371">ML.ENERGY</a>),
          so they count at 0.45.
        </p>

        <p>
          For the rest, whose hardware isn't published, the estimate uses published
          measurements instead. Image models use energy in proportion to how many steps
          they take to refine an image, from about 0.45 Wh at 10 steps to 2.1 Wh at 50 for
          a large model (<a href="https://arxiv.org/abs/2511.17031">Energy Scaling Laws for Diffusion Models</a>),
          so an image counts as 0.15 Wh from a fast few-step model and 1.0 Wh from a
          larger one. For text, a large model's reply counts as about 0.3 Wh (<a href="https://epoch.ai/gradient-updates/how-much-energy-does-chatgpt-use">Epoch AI</a>,
          in line with <a href="https://arxiv.org/abs/2508.15734">Google's 0.24 Wh</a>
          for a typical Gemini prompt), and a smaller model's (like Claude Haiku or Gemini
          Flash) about a third of that. Generated music counts as 0.057 Wh per second of
          audio (<a href="https://arxiv.org/abs/2609.18585">TTM-Bench</a>).
        </p>

        <p>
          To make the numbers easier to picture, they're compared with everyday things: a
          10 W LED bulb, charging a phone (about 15 Wh) or boiling a litre of water in a
          kettle (about 100 Wh). The estimates leave out the energy used to train the
          models, which is spread across every use of them and is much harder to pin down.
        </p>

        <p><.link navigate={~p"/about"}>Back to About PANIC!</.link></p>
      </div>
    </Layouts.app>
    """
  end
end

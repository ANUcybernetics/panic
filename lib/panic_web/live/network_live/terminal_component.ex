defmodule PanicWeb.NetworkLive.TerminalComponent do
  @moduledoc false
  use PanicWeb, :live_component

  alias Panic.Engine.Invocation
  alias Panic.Engine.NetworkRunner

  @impl true
  def render(assigns) do
    ~H"""
    <div class={assigns[:class]}>
      <.simple_form
        for={@form}
        id={"#{@id}-form"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="start-run"
      >
        <.input
          field={@form[:input]}
          type="text"
          label="Prompt"
          placeholder={lockout_placeholder(@lockout_seconds_remaining)}
          disabled={@lockout_seconds_remaining > 0}
        />
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Default lockout_seconds_remaining if not provided
    lockout_seconds_remaining = Map.get(assigns, :lockout_seconds_remaining, 0)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(lockout_seconds_remaining: lockout_seconds_remaining)
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"invocation" => invocation_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, invocation_params))}
  end

  def handle_event("start-run", %{"invocation" => invocation_params}, socket) do
    prompt = invocation_params["input"] || ""

    case NetworkRunner.start_run(socket.assigns.network.id, prompt, socket.assigns.current_user) do
      {:ok, genesis_invocation} ->
        notify_parent({:genesis_invocation, genesis_invocation})
        socket = assign(socket, :genesis_invocation, genesis_invocation)
        {:noreply, assign_form(socket)}

      {:lockout, genesis_invocation} ->
        socket =
          socket
          |> put_flash(:error, "Please wait before starting a new run")
          |> assign(:genesis_invocation, genesis_invocation)

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, AshPhoenix.Form.errors(form))
          |> assign(form: form)

        {:noreply, socket}
    end
  end

  defp assign_form(%{assigns: %{network: network}} = socket) do
    form =
      AshPhoenix.Form.for_create(Invocation, :prepare_first,
        as: "invocation",
        prepare_source: fn changeset ->
          Ash.Changeset.set_argument(changeset, :network, network)
        end,
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp lockout_placeholder(seconds_remaining) when seconds_remaining > 0 do
    "#{seconds_remaining} second#{if seconds_remaining == 1, do: "", else: "s"} until ready for new input"
  end

  defp lockout_placeholder(_), do: "Ready for new input"
end

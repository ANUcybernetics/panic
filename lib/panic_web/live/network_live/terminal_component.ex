defmodule PanicWeb.NetworkLive.TerminalComponent do
  @moduledoc false
  use PanicWeb, :live_component

  alias Panic.Engine.Invocation

  @impl true
  def render(assigns) do
    ~H"""
    <div>
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
          phx-hook="TerminalLockoutTimer"
          data-ready-at={@ready_at}
          placeholder="Starting up..."
        />
        <:actions>
          <.button phx-disable-with="Let's go...">PANIC!</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    ready_at =
      case assigns.genesis_invocation do
        %Invocation{inserted_at: inserted_at} -> DateTime.add(inserted_at, 30, :second)
        nil -> DateTime.utc_now(:second)
      end

    {:ok,
     socket
     |> assign(ready_at: ready_at)
     |> assign(assigns)
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"invocation" => invocation_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, invocation_params))}
  end

  def handle_event("start-run", %{"invocation" => invocation_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: invocation_params) do
      {:ok, invocation} ->
        socket =
          case Panic.Engine.start_run(invocation, actor: socket.assigns.current_user) do
            :ok ->
              put_flash(socket, :info, "Invocation #{invocation.id} prepared... about to run")

            # TODO there's gotta be a nicer way to wrap the error in the generic :start_run
            # action so that I don't have to destructure it like this
            {:error, %Ash.Error.Unknown{errors: [%Ash.Error.Unknown.UnknownError{error: :network_not_ready}]}} ->
              put_flash(socket, :info, "Network not ready for re-prompting - hang tight.")

            {:error, _reason} ->
              put_flash(socket, :error, "Error: couldn't start run because reasons.")
          end

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
end

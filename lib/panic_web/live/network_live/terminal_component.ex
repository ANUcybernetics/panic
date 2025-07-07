defmodule PanicWeb.NetworkLive.TerminalComponent do
  @moduledoc false
  use PanicWeb, :live_component

  alias Panic.Engine.Invocation
  alias Panic.Engine.NetworkRunner

  @impl true
  def render(assigns) do
    ~H"""
    <div class={assigns[:class]}>
      <style>
        #<%= "#{@id}-form" %> .mt-10 {
          margin-top: 1rem;
        }
        #<%= "#{@id}-form" %> .space-y-8 {
          gap: 1rem;
        }
        @media (max-width: 640px) {
          #<%= "#{@id}-form" %> input[type="text"] {
            font-size: 1rem !important;
            padding: 0.5rem !important;
          }
          #<%= "#{@id}-form" %> label {
            font-size: 0.875rem;
          }
          #<%= "#{@id}-form" %> .mt-2 {
            margin-top: 0.5rem;
          }
        }
      </style>
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

    case NetworkRunner.start_run(socket.assigns.network.id, prompt) do
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

      {:error, error} ->
        # Handle both form errors and exceptions
        {error_message, form_to_assign} =
          case error do
            %AshPhoenix.Form{} = form ->
              # It's a form with validation errors
              {AshPhoenix.Form.errors(form), form}

            %Phoenix.HTML.Form{source: %AshPhoenix.Form{}} = form ->
              # It's a Phoenix form wrapping an Ash form
              {AshPhoenix.Form.errors(form), form}

            exception when is_exception(exception) ->
              # It's an exception (e.g., from missing API tokens)
              message = Exception.message(exception)
              {message, socket.assigns.form}

            _ ->
              # Unknown error type
              {"An error occurred while starting the run", socket.assigns.form}
          end

        socket =
          socket
          |> put_flash(:error, error_message)
          |> assign(form: form_to_assign)

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

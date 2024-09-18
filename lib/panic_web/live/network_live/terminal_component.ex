defmodule PanicWeb.NetworkLive.TerminalComponent do
  @moduledoc false
  use PanicWeb, :live_component

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
        <.input field={@form[:input]} type="text" label="Prompt..." />
        <:actions>
          <.button phx-disable-with="Let's go...">PANIC!</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
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
        Panic.Engine.start_run!(invocation, actor: socket.assigns.current_user)
        notify_parent({:new_invocation, invocation})

        socket =
          put_flash(socket, :info, "Invocation #{invocation.id} prepared... about to run")

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, AshPhoenix.Form.errors(form))
          |> assign(form: form)

        {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: network}} = socket) do
    form =
      AshPhoenix.Form.for_create(Panic.Engine.Invocation, :prepare_first,
        as: "invocation",
        prepare_source: fn changeset ->
          Ash.Changeset.set_argument(changeset, :network, network)
        end,
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end
end

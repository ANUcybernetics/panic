defmodule PanicWeb.NetworkLive.TerminalComponent do
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <.simple_form
      for={@form}
      id={@id <> "-form"}
      phx-target={@myself}
      phx-change="validate"
      phx-submit="create-and-run"
    >
      <.input field={@form[:input]} type="text" label="Prompt..." />
      <:actions>
        <.button phx-disable-with="Let's go...">PANIC!</.button>
      </:actions>
    </.simple_form>
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
    {:noreply,
     assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, invocation_params))}
  end

  def handle_event("create-and-go", %{"invocation" => invocation_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: invocation_params) do
      {:ok, invocation} ->
        socket =
          socket
          |> put_flash(:info, "Invocation #{invocation.id} prepared... about to run")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  # defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: _network}} = socket) do
    form =
      AshPhoenix.Form.for_create(Panic.Engine.Invocation, :prepare_first,
        as: "invocation",
        actor: socket.current_user
      )

    assign(socket, form: to_form(form))
  end
end

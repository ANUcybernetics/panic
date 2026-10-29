defmodule PanicWeb.InstallationLive.FormComponent do
  @moduledoc """
  Form component for creating and editing installations.
  """
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          {if @action == :new, do: "Create a new installation", else: "Update installation details"}
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="installation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <.input
          field={@form[:network_id]}
          type="select"
          label="Network"
          options={Enum.map(@networks, &{&1.name, &1.id})}
        />

        <.input
          field={@form[:vestaboard_hold_seconds]}
          type="number"
          min="0"
          label="Vestaboard hold (seconds)"
        >
          <:help>
            After a Vestaboard is sent text, the next output waits at least this long before it's shown, so it doesn't change while the board is still flipping.
          </:help>
        </.input>

        <div class="mt-6 flex flex-wrap gap-2">
          <.button variant="primary" phx-disable-with="Saving...">Save Installation</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    socket = if socket.assigns[:form], do: socket, else: assign_form(socket)
    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, installation} ->
        notify_parent({:saved, installation})

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Installation #{if socket.assigns.action == :new, do: "created", else: "updated"} successfully"
         )
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(%{assigns: %{action: action, current_user: actor}} = socket) do
    form =
      case action do
        :new ->
          Panic.Watcher.form_to_create_installation(actor: actor)

        :edit ->
          Panic.Watcher.form_to_update_installation(socket.assigns.installation, actor: actor)
      end

    assign(socket, :form, to_form(form))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end

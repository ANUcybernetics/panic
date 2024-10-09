defmodule PanicWeb.NetworkLive.FormComponent do
  @moduledoc false
  use PanicWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>

      <.simple_form
        for={@form}
        id="network-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Network</.button>
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
  def handle_event("validate", %{"network" => network_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, network_params))}
  end

  def handle_event("save", %{"network" => network_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: network_params) do
      {:ok, network} ->
        notify_parent({:saved, network})

        socket =
          socket
          |> put_flash(:info, "Network #{socket.assigns.form.source.type}d successfully")
          |> push_navigate(to: socket.assigns.navigate)

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{network: network}} = socket) do
    # NOTE: this was the auto-generated "default action" stuff, which currently
    # isn't what I want, but in the interests of getting it to compile I'll do it like this
    form =
      if network do
        AshPhoenix.Form.for_update(network, :update,
          as: "network",
          actor: socket.assigns.current_user
        )
      else
        AshPhoenix.Form.for_create(Panic.Engine.Network, :create,
          as: "network",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end
end

defmodule PanicWeb.APITokenLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Manage your AI platform API tokens.</:subtitle>
      </.header>

      <.simple_form
        :let={f}
        for={@changeset}
        id="api_token-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={{f, :name}} type="text" label="Name" />
        <.input field={{f, :token}} type="text" label="Token" />
        <:actions>
          <.button phx-disable-with="Saving...">Save API token</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{api_token: api_token} = assigns, socket) do
    changeset = Accounts.change_api_token(api_token)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"api_token" => api_token_params}, socket) do
    changeset =
      socket.assigns.api_token
      |> Accounts.change_api_token(api_token_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"api_token" => api_token_params}, socket) do
    api_token_params = Map.put(api_token_params, "user_id", socket.assigns.user.id)
    save_api_token(socket, socket.assigns.action, api_token_params)
  end

  defp save_api_token(socket, :edit, api_token_params) do
    case Accounts.update_api_token(socket.assigns.api_token, api_token_params) do
      {:ok, _api_token} ->
        {:noreply,
         socket
         |> put_flash(:info, "API token updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_api_token(socket, :new, api_token_params) do
    case Accounts.create_api_token(api_token_params) do
      {:ok, _api_token} ->
        {:noreply,
         socket
         |> put_flash(:info, "API token created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

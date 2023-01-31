defmodule PanicWeb.APITokenLive.FormComponent do
  use PanicWeb, :live_component

  alias Panic.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage api_tokens records in your database.</:subtitle>
      </.header>

      <.simple_form
        :let={f}
        for={@changeset}
        id="api_tokens-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={{f, :name}} type="text" label="Name" />
        <.input field={{f, :token}} type="text" label="Token" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Api tokens</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{api_tokens: api_tokens} = assigns, socket) do
    changeset = Accounts.change_api_tokens(api_tokens)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"api_tokens" => api_tokens_params}, socket) do
    changeset =
      socket.assigns.api_tokens
      |> Accounts.change_api_tokens(api_tokens_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"api_tokens" => api_tokens_params}, socket) do
    save_api_tokens(socket, socket.assigns.action, api_tokens_params)
  end

  defp save_api_tokens(socket, :edit, api_tokens_params) do
    case Accounts.update_api_tokens(socket.assigns.api_tokens, api_tokens_params) do
      {:ok, _api_tokens} ->
        {:noreply,
         socket
         |> put_flash(:info, "Api tokens updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_api_tokens(socket, :new, api_tokens_params) do
    case Accounts.create_api_tokens(api_tokens_params) do
      {:ok, _api_tokens} ->
        {:noreply,
         socket
         |> put_flash(:info, "Api tokens created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

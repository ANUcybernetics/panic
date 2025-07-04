defmodule PanicWeb.APITokenLive.FormComponent do
  @moduledoc """
  Form component for creating and editing API tokens.
  """
  use PanicWeb, :live_component

  alias Panic.Accounts.APIToken

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Manage your API tokens for various platforms.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="api_token-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" placeholder="My API Tokens" />

        <div class="space-y-4 border-t border-gray-200 pt-4">
          <h3 class="text-sm font-medium text-gray-900">Platform Tokens</h3>
          <.input field={@form[:openai_token]} type="password" label="OpenAI API Token" />
          <.input field={@form[:replicate_token]} type="password" label="Replicate API Token" />
          <.input field={@form[:gemini_token]} type="password" label="Gemini API Token" />
        </div>

        <div class="space-y-4 border-t border-gray-200 pt-4">
          <h3 class="text-sm font-medium text-gray-900">Vestaboard Tokens</h3>
          <.input field={@form[:vestaboard_panic_1_token]} type="password" label="Vestaboard Panic 1" />
          <.input field={@form[:vestaboard_panic_2_token]} type="password" label="Vestaboard Panic 2" />
          <.input field={@form[:vestaboard_panic_3_token]} type="password" label="Vestaboard Panic 3" />
          <.input field={@form[:vestaboard_panic_4_token]} type="password" label="Vestaboard Panic 4" />
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">Save API Token</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{api_token: api_token} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(api_token, assigns.action)}
  end

  @impl true
  def handle_event("validate", %{"api_token" => api_token_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, api_token_params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"api_token" => api_token_params}, socket) do
    save_api_token(socket, socket.assigns.action, api_token_params)
  end

  defp save_api_token(socket, :edit, api_token_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: api_token_params) do
      {:ok, api_token} ->
        notify_parent({:saved, api_token})

        {:noreply,
         socket
         |> put_flash(:info, "API token updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp save_api_token(socket, :new, api_token_params) do
    # Submit the form
    case AshPhoenix.Form.submit(socket.assigns.form, params: api_token_params) do
      {:ok, api_token} ->
        # Associate the token with the current user
        case associate_token_with_user(api_token, socket.assigns.current_user) do
          :ok ->
            notify_parent({:saved, api_token})

            {:noreply,
             socket
             |> put_flash(:info, "API token created successfully")
             |> push_patch(to: socket.assigns.patch)}

          {:error, _} ->
            # Clean up the token if association fails
            Ash.destroy!(api_token, actor: socket.assigns.current_user, authorize?: false)

            {:noreply,
             socket
             |> put_flash(:error, "Failed to associate token with user")
             |> assign_form(socket.assigns.api_token, :new)}
        end

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp associate_token_with_user(api_token, user) do
    # Create the join table entry
    case Ash.create(
           Panic.Accounts.UserAPIToken,
           %{
             user_id: user.id,
             api_token_id: api_token.id
           },
           authorize?: false
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp assign_form(socket, api_token, action) do
    case_result =
      case action do
        :new ->
          AshPhoenix.Form.for_create(APIToken, :create,
            as: "api_token",
            actor: socket.assigns.current_user
          )

        :edit ->
          AshPhoenix.Form.for_update(api_token, :update,
            as: "api_token",
            actor: socket.assigns.current_user
          )
      end

    form = to_form(case_result)

    assign(socket, form: form)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end

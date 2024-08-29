defmodule PanicWeb.UserLive.FormComponent do
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
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <%!-- Attributes for the parent resource --%>
        <.input type="email" label="Email" field={@form[:email]} />
        <%!-- Render nested forms for related data --%>
        <.inputs_for :let={api_token_form} field={@form[:api_tokens]}>
          <.input
            type="select"
            label="Name"
            field={api_token_form[:name]}
            options={[
              :replicate,
              :openai,
              :vestaboard_panic_1,
              :vestaboard_panic_2,
              :vestaboard_panic_3,
              :vestaboard_panic_4
            ]}
          />

          <.input type="text" label="Token" field={api_token_form[:value]} />
          <.button
            type="button"
            phx-click="remove_token"
            phx-value-path={api_token_form.name}
            phx-target={@myself}
          >
            Remove
          </.button>
        </.inputs_for>
        <:actions>
          <.button
            type="button"
            phx-click="add_token"
            phx-value-path={@form[:api_tokens].name}
            phx-target={@myself}
          >
            Add API Token
          </.button>
          <.button>Save</.button>
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
  def handle_event("validate", %{"user" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params
         ) do
      {:ok, user} ->
        notify_parent({:saved, user})

        socket =
          socket
          |> put_flash(:info, "User #{socket.assigns.form.source.type}d successfully")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("add_token", %{"path" => params}, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("remove_token", %{"path" => params}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event(_, _params, socket) do
    {:noreply, socket}
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{user: user}} = socket) do
    form =
      user
      |> AshPhoenix.Form.for_update(:update,
        forms: [
          api_tokens: [
            type: :list,
            data: user.api_tokens,
            resource: Panic.Accounts.ApiToken,
            update_action: :update,
            create_action: :create
          ]
        ],
        as: "user",
        actor: socket.assigns.current_user
      )
      |> AshPhoenix.Form.add_form([:api_tokens])
      |> to_form()

    assign(socket, form: to_form(form))
  end
end

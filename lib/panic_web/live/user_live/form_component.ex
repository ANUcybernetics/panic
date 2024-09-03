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
        <.input type="email" label="Email" field={@form[:email]} />
        <.input type="text" label="Replicate API Token" field={@form[:replicate_token]} />
        <.input type="text" label="OpenAI API Token" field={@form[:openai_token]} />
        <.input
          type="text"
          label="Vestaboard Panic 1 API Token"
          field={@form[:vestaboard_panic_1_token]}
        />
        <.input
          type="text"
          label="Vestaboard Panic 2 API Token"
          field={@form[:vestaboard_panic_2_token]}
        />
        <.input
          type="text"
          label="Vestaboard Panic 3 API Token"
          field={@form[:vestaboard_panic_3_token]}
        />
        <.input
          type="text"
          label="Vestaboard Panic 4 API Token"
          field={@form[:vestaboard_panic_4_token]}
        />
        <:actions>
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

  def handle_event(_, _params, socket) do
    {:noreply, socket}
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{user: user}} = socket) do
    form =
      user
      |> AshPhoenix.Form.for_update(:update_tokens,
        as: "user",
        actor: socket.assigns[:current_user]
      )
      |> to_form()

    assign(socket, form: form)
  end
end

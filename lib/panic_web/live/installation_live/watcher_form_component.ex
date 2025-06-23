defmodule PanicWeb.InstallationLive.WatcherFormComponent do
  @moduledoc """
  Form component for adding watchers to installations.
  """
  use PanicWeb, :live_component

  alias Panic.Engine.Installation.Watcher

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          Configure how invocations should be displayed
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="watcher-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.inputs_for :let={watcher_form} field={@form[:watcher]}>
          <.input
            field={watcher_form[:type]}
            type="select"
            label="Type"
            options={[
              {"Grid - Display invocations in a grid layout", :grid},
              {"Single - Show one invocation at a time", :single},
              {"Vestaboard - Display for Vestaboard device", :vestaboard}
            ]}
          />

          <div :if={watcher_form[:type].value == :grid} class="space-y-4">
            <.input field={watcher_form[:rows]} type="number" label="Rows" min="1" />
            <.input field={watcher_form[:columns]} type="number" label="Columns" min="1" />
          </div>

          <div :if={watcher_form[:type].value in [:single, :vestaboard]} class="space-y-4">
            <.input field={watcher_form[:stride]} type="number" label="Stride" min="1" />
            <.input field={watcher_form[:offset]} type="number" label="Offset" min="0" />
            <.input field={watcher_form[:show_invoking]} type="checkbox" label="Show Invoking State" />
            <p class="mt-1 text-sm text-gray-600">
              When enabled, invocations in the 'invoking' state will be displayed. When disabled, only completed, ready, and failed states are shown.
            </p>
          </div>

          <div :if={watcher_form[:type].value == :vestaboard} class="space-y-4">
            <.input
              field={watcher_form[:name]}
              type="select"
              label="Vestaboard Name"
              options={[
                {"Panic 1", :panic_1},
                {"Panic 2", :panic_2},
                {"Panic 3", :panic_3},
                {"Panic 4", :panic_4}
              ]}
            />
            <.input field={watcher_form[:initial_prompt]} type="checkbox" label="Show Initial Prompt" />
            <p class="mt-1 text-sm text-gray-600">
              When enabled, this vestaboard will display the initial prompt text when a new run starts
            </p>
          </div>
        </.inputs_for>

        <:actions>
          <.button phx-disable-with="Adding...">Add Watcher</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    form =
      AshPhoenix.Form.for_update(assigns.installation, :add_watcher,
        params: %{watcher: %{type: :grid}},
        actor: assigns.current_user,
        forms: [watcher: [resource: Watcher, create_action: :create]]
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(form)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.installation
      |> AshPhoenix.Form.for_update(:add_watcher,
        params: params,
        actor: socket.assigns.current_user,
        forms: [
          watcher: [
            resource: Watcher,
            create_action: :create
          ]
        ]
      )
      |> AshPhoenix.Form.validate(params)

    {:noreply, assign_form(socket, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case socket.assigns.installation
         |> AshPhoenix.Form.for_update(:add_watcher,
           params: params,
           actor: socket.assigns.current_user,
           forms: [
             watcher: [
               resource: Watcher,
               create_action: :create
             ]
           ]
         )
         |> AshPhoenix.Form.submit(params: params) do
      {:ok, installation} ->
        installation = Ash.load!(installation, [:network], actor: socket.assigns.current_user)
        notify_parent({:saved, installation})

        {:noreply,
         socket
         |> put_flash(:info, "Watcher added successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign_form(socket, form)}
    end
  end

  defp assign_form(socket, %AshPhoenix.Form{} = form) do
    assign(socket, :form, to_form(form))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end

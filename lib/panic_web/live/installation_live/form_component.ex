defmodule PanicWeb.InstallationLive.FormComponent do
  @moduledoc """
  Form component for creating and editing installations.
  """
  use PanicWeb, :live_component

  alias Panic.Engine.Installation

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

      <.simple_form
        for={@form}
        id="installation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <.input
          :if={@action == :new}
          field={@form[:network_id]}
          type="select"
          label="Network"
          options={Enum.map(@networks, &{&1.name, &1.id})}
        />

        <:actions>
          <.button phx-disable-with="Saving...">Save Installation</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{installation: installation} = assigns, socket) do
    changeset =
      case assigns.action do
        :new ->
          AshPhoenix.Form.for_create(Installation, :create,
            actor: assigns.current_user,
            forms: [auto?: true]
          )

        :edit ->
          AshPhoenix.Form.for_update(installation, :update,
            actor: assigns.current_user,
            forms: [auto?: true]
          )
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"form" => installation_params}, socket) do
    form =
      case socket.assigns.action do
        :new ->
          Installation
          |> AshPhoenix.Form.for_create(:create,
            params: installation_params,
            actor: socket.assigns.current_user,
            forms: [auto?: true]
          )
          |> AshPhoenix.Form.validate(installation_params)

        :edit ->
          socket.assigns.installation
          |> AshPhoenix.Form.for_update(:update,
            params: installation_params,
            actor: socket.assigns.current_user,
            forms: [auto?: true]
          )
          |> AshPhoenix.Form.validate(installation_params)
      end

    {:noreply, assign_form(socket, form)}
  end

  def handle_event("save", %{"form" => installation_params}, socket) do
    save_installation(socket, socket.assigns.action, installation_params)
  end

  defp save_installation(socket, :new, installation_params) do
    case Installation
         |> AshPhoenix.Form.for_create(:create,
           params: installation_params,
           actor: socket.assigns.current_user,
           forms: [auto?: true]
         )
         |> AshPhoenix.Form.submit(params: installation_params) do
      {:ok, installation} ->
        notify_parent({:saved, installation})

        {:noreply,
         socket
         |> put_flash(:info, "Installation created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign_form(socket, form)}
    end
  end

  defp save_installation(socket, :edit, installation_params) do
    case socket.assigns.installation
         |> AshPhoenix.Form.for_update(:update,
           params: installation_params,
           actor: socket.assigns.current_user,
           forms: [auto?: true]
         )
         |> AshPhoenix.Form.submit(params: installation_params) do
      {:ok, installation} ->
        notify_parent({:saved, installation})

        {:noreply,
         socket
         |> put_flash(:info, "Installation updated successfully")
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

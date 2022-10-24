defmodule PanicWeb.AdminJobsLive do
  use PanicWeb, :live_view
  import PanicWeb.AdminLayoutComponent

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Jobs")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, assign(socket, url: url)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_layout current_page={:admin_jobs} current_user={@current_user}>
      <.page_header title={@page_title} />
      <AlpineComponents.js_setup />

      <.live_component id="users-table" module={DataTable} url={@url} ecto_query={Oban.Job}>
        <:col field={:id} sortable /><:col field={:state} sortable filterable={[:=~]} /><:col
          field={:queue}
          sortable
          filterable={[:=~]}
        />
        <:col :let={job} field={:args}>
          <AlpineComponents.truncate lines={1}>
            <%= inspect(job.args) %>
          </AlpineComponents.truncate>
        </:col>
        <:col :let={job} field={:attempt}>
          <%= job.attempt %>/<%= job.max_attempts %>
        </:col>
        <:col :let={job} field={:errors}>
          <%= if job.state in ["completed", "discarded", "cancelled"] do %>
            NA
          <% else %>
            <AlpineComponents.truncate lines={2}>
              <%= inspect(job.errors) %>
            </AlpineComponents.truncate>
          <% end %>
        </:col>
        <:col :let={job} label="">
          <div class="flex gap-2">
            <%= if job.state == "retryable" do %>
              <.button size="sm" label="Retry" color="white" phx-click="retry" phx-value-id={job.id} />
            <% end %>

            <%= if !Enum.member?(["cancelled", "discarded", "completed"], job.state) do %>
              <.button
                size="sm"
                label="Cancel"
                color="danger"
                phx-click="cancel"
                phx-value-id={job.id}
              />
            <% end %>
          </div>
        </:col>
      </.live_component>
    </.admin_layout>
    """
  end

  def render_name(item) do
    item.name <> " " <> item.email
  end

  @impl true
  def handle_event("retry", %{"id" => oban_id}, socket) do
    Oban.retry_job(oban_id |> String.to_integer())

    socket =
      socket
      |> put_flash(:success, "Job retrying")
      |> push_redirect(to: Routes.live_path(socket, __MODULE__))

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", %{"id" => oban_id}, socket) do
    Oban.cancel_job(oban_id |> String.to_integer())

    socket =
      socket
      |> put_flash(:success, "Job cancelled")
      |> push_redirect(to: Routes.live_path(socket, __MODULE__))

    {:noreply, socket}
  end
end

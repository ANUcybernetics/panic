defmodule PetalProWeb.LogsLive do
  @moduledoc """
  A component to display a list of logs. Logs are actions performed by users, and can help you discover how your application is used.
  """
  use PetalProWeb, :live_view
  alias PetalPro.{Repo, Accounts}
  alias PetalPro.Logs.{LogQuery}
  alias PetalProWeb.LogsLive.SearchChangeset
  import PetalProWeb.AdminLayoutComponent

  @log_preloads [
    :user,
    :target_user
  ]

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PetalProWeb.Endpoint.subscribe("logs")
    end

    socket =
      socket
      |> assign(%{
        page_title: "Logs",
        load_more: false,
        action: "",
        limit: 20,
        search_changeset: SearchChangeset.build(%{})
      })

    {:ok, set_logs(socket)}
  end

  def handle_params(params, uri, socket) do
    socket =
      socket
      |> assign(%{
        path: URI.parse(uri).path,
        search_changeset: SearchChangeset.build(params)
      })
      |> set_logs()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => search_params}, socket) do
    {:noreply, push_patch(socket, to: Routes.logs_path(socket, :index, search_params))}
  end

  def handle_event("load-more", _, socket) do
    socket =
      socket
      |> update(:limit, fn limit -> limit + 10 end)
      |> set_logs()

    {:noreply, socket}
  end

  def handle_info(
        %{
          topic: "logs",
          event: "new-log",
          payload: log
        },
        socket
      ) do
    if socket.assigns.search_changeset.changes[:enable_live_logs] do
      log = Repo.preload(log, @log_preloads)

      {:noreply, assign(socket, logs: [log | socket.assigns.logs])}
    else
      {:noreply, socket}
    end
  end

  def set_logs(socket) do
    case SearchChangeset.validate(socket.assigns.search_changeset) do
      {:ok, search} ->
        query =
          LogQuery.by_action(search[:action])
          |> LogQuery.limit(socket.assigns.limit)
          |> LogQuery.order_by(:newest)
          |> LogQuery.preload(@log_preloads)

        query =
          if search[:user_id] do
            user = Accounts.get_user!(search.user_id)
            LogQuery.by_user(query, user.id)
          else
            query
          end

        logs = Repo.all(query)

        assign(socket, %{logs: logs, load_more: length(logs) >= socket.assigns.limit})

      {:error, changeset} ->
        assign(socket, %{
          search_changeset: changeset,
          logs: []
        })
    end
  end

  defp maybe_add_emoji("register"), do: "🥳"
  defp maybe_add_emoji("sign_in"), do: "🙌"
  defp maybe_add_emoji("delete_user"), do: "💀"
  defp maybe_add_emoji("confirm_new_email"), do: "📧"
  defp maybe_add_emoji("orgs.create"), do: "🏢"
  defp maybe_add_emoji(_), do: ""
end

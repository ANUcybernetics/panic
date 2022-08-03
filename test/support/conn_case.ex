defmodule PetalProWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PetalProWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  alias PetalFramework.Extensions.Ecto.QueryExt

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PetalProWeb.ConnCase
      import Swoosh.TestAssertions

      alias PetalProWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint PetalProWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PetalPro.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_sign_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_sign_in_user(%{conn: conn}) do
    user =
      PetalPro.AccountsFixtures.user_fixture(%{
        is_onboarded: true,
        confirmed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      })

    org = PetalPro.OrgsFixtures.org_fixture(user)
    membership = PetalPro.Orgs.get_membership!(user, org.slug)
    %{conn: log_in_user(conn, user), user: user, org: org, membership: membership}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = PetalPro.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc """
  This function tests that the route can't be accessed by an anonymous user.
  """
  def assert_route_protected(live_result) do
    {:error, {:redirect, %{flash: flash, to: to}}} = live_result
    assert flash["error"] =~ "You must log in to access this page"
    assert to =~ PetalProWeb.Router.Helpers.user_session_path(PetalProWeb.Endpoint, :new)
  end

  def assert_log(action, params \\ %{}) do
    log =
      PetalPro.Logs.LogQuery.by_action(action)
      |> PetalPro.Logs.LogQuery.order_by(:newest)
      |> QueryExt.limit(1)
      |> PetalPro.Repo.one()

    assert !!log, ~s|No log found for action "#{action}"|

    Enum.each(params, fn {k, v} ->
      assert(
        Map.get(log, k) == v,
        "log.#{k} should equal #{inspect(v)}, but it equals #{inspect(Map.get(log, k))} \n\n #{inspect(log)}"
      )
    end)
  end
end

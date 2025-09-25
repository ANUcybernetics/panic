defmodule Panic.TestPerformance do
  @moduledoc """
  Test performance optimization utilities.

  Provides caching and optimization strategies for test fixtures to reduce
  test suite execution time while maintaining test isolation.
  """

  @doc """
  Creates a user with caching within the same test process.

  This reduces the overhead of user creation when multiple users
  are needed in a single test. Each test process still gets its
  own isolated users.
  """
  def cached_user(key \\ :default) do
    cache_key = {:test_user_cache, key}

    case Process.get(cache_key) do
      nil ->
        user = Panic.Fixtures.user()
        Process.put(cache_key, user)
        user

      user ->
        user
    end
  end

  @doc """
  Creates an authenticated connection with a cached user.

  Combines user caching with authentication setup for LiveView tests.
  """
  def cached_authenticated_conn(conn, key \\ :default) do
    user = cached_user(key)
    password = "abcd1234"

    strategy = AshAuthentication.Info.strategy!(Panic.Accounts.User, :password)

    {:ok, authenticated_user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: user.email,
        password: password
      })

    authenticated_conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(authenticated_user)

    {authenticated_conn, authenticated_user}
  end

  @doc """
  Optimized setup for LiveView tests that need authentication and networks.

  Combines multiple setup steps into one efficient function:
  - Stops NetworkRunners once
  - Creates cached users
  - Sets up authentication
  - Creates networks with models
  """
  def setup_authenticated_live_test(%{conn: conn} = context) do
    # Clean up NetworkRunners once
    PanicWeb.Helpers.stop_all_network_runners()

    # Enable sync mode for predictable tests
    PanicWeb.Helpers.enable_sync_network_runner()

    # Create authenticated connection with cached user
    {authenticated_conn, user} = cached_authenticated_conn(conn)

    # Setup cleanup
    ExUnit.Callbacks.on_exit(fn ->
      PanicWeb.Helpers.disable_sync_network_runner()
    end)

    Map.merge(context, %{
      conn: authenticated_conn,
      user: user
    })
  end

  @doc """
  Batch creates multiple networks for a user.

  More efficient than creating networks one by one.
  """
  def batch_create_networks(user, count) do
    1..count
    |> Enum.map(fn i ->
      Panic.Generators.network_with_dummy_models(user)
      |> StreamData.map(fn network ->
        Map.put(network, :name, "Test Network #{i}")
      end)
      |> Enum.take(1)
      |> List.first()
    end)
  end
end
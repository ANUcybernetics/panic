# Configure ExUnit to exclude API tests by default
exclude_tags =
  if System.get_env("OPENAI_API_KEY") && System.get_env("REPLICATE_API_KEY") do
    []
  else
    [api_required: true]
  end

ExUnit.start(exclude: exclude_tags)
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  alias Panic.Accounts.User
  alias Panic.Engine.Network
  alias Panic.Platforms.Vestaboard

  def ascii_sentence do
    :ascii
    |> string(min_length: 1)
    |> map(&String.trim/1)
    |> filter(&(String.length(&1) > 0))
  end

  def model(filters \\ []) do
    filters
    |> Panic.Model.all()
    |> member_of()
    |> filter(fn model -> model.platform != Vestaboard end)
  end

  def password do
    :utf8
    |> string(min_length: 8)
    |> filter(fn s -> not Regex.match?(~r/^[[:space:]]*$/, s) end)
    |> filter(fn s -> String.length(s) >= 8 end)
  end

  def email do
    fn -> System.unique_integer([:positive]) end
    |> repeatedly()
    |> map(fn i -> "user-#{i}@example.com" end)
  end

  def user(password_generator \\ password()) do
    gen all(email <- email(), password <- password_generator) do
      User
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: password, password_confirmation: password}
      )
      |> Ash.create!()
    end
  end

  def set_all_tokens(user) do
    # Read API keys from environment variables if available, otherwise use test tokens
    openai_key = System.get_env("OPENAI_API_KEY") || Application.get_env(:panic, :api_tokens)[:openai_token]
    replicate_key = System.get_env("REPLICATE_API_KEY") || Application.get_env(:panic, :api_tokens)[:replicate_token]

    # Set available tokens
    user = if openai_key, do: Panic.Accounts.set_token!(user, :openai_token, openai_key, actor: user), else: user
    user = if replicate_key, do: Panic.Accounts.set_token!(user, :replicate_token, replicate_key, actor: user), else: user

    # Set other test tokens from config
    :panic
    |> Application.get_env(:api_tokens)
    |> Enum.filter(fn {name, _value} -> name not in [:openai_token, :replicate_token] end)
    |> Enum.reduce(user, fn {name, value}, acc ->
      Panic.Accounts.set_token!(acc, name, value, actor: acc)
    end)
  end

  def set_real_api_tokens!(user) do
    # Read API keys from environment variables
    openai_key = System.get_env("OPENAI_API_KEY")
    replicate_key = System.get_env("REPLICATE_API_KEY")

    # For api_required tests, fail if keys are not present
    if openai_key == nil || replicate_key == nil do
      raise "API keys required for this test. Set OPENAI_API_KEY and REPLICATE_API_KEY environment variables."
    end

    # Set the tokens from environment variables
    user
    |> Panic.Accounts.set_token!(:openai_token, openai_key, actor: user)
    |> Panic.Accounts.set_token!(:replicate_token, replicate_key, actor: user)
  end

  def user_with_tokens do
    gen all(user <- user()) do
      user = set_all_tokens(user)
      Ash.get!(User, user.id, actor: user)
    end
  end

  def user_with_real_tokens do
    gen all(user <- user()) do
      user = set_real_api_tokens!(user)
      Ash.get!(User, user.id, actor: user)
    end
  end

  def network(user) do
    gen all(input <- Ash.Generator.action_input(Network, :create)) do
      Network
      |> Ash.Changeset.for_create(:create, input, actor: user)
      |> Ash.create!()
    end
  end

  def network_with_models(user) do
    gen all(network <- network(user), length <- integer(1..10)) do
      model_ids =
        :text
        |> Stream.unfold(fn input_type ->
          next_model = [input_type: input_type] |> model() |> pick()
          {next_model, Map.fetch!(next_model, :output_type)}
        end)
        |> Stream.transform([], fn model, acc ->
          if length(acc) >= length && acc |> List.last() |> Map.fetch!(:output_type) == :text do
            {:halt, acc}
          else
            {[model], acc ++ [model]}
          end
        end)
        |> Enum.map(fn %Panic.Model{id: id} -> [id] end)

      Panic.Engine.update_models!(network, model_ids, actor: user)
    end
  end

  def invocation(network) do
    user = Ash.get!(User, network.user_id, authorize?: false)

    gen all(input <- Panic.Generators.ascii_sentence()) do
      Panic.Engine.Invocation
      |> Ash.Changeset.for_create(:prepare_first, %{input: input, network: network}, actor: user)
      |> Ash.create!()
    end
  end
end

# seed 768476
defmodule Panic.Fixtures do
  @moduledoc """
  Test fixtures for Panic resources.
  """
  use ExUnitProperties

  def user(password) do
    password
    |> StreamData.constant()
    |> Panic.Generators.user()
    |> pick()
  end

  def user do
    pick(Panic.Generators.user())
  end

  def user_with_tokens do
    pick(Panic.Generators.user_with_tokens())
  end

  def user_with_real_tokens do
    pick(Panic.Generators.user_with_real_tokens())
  end

  def network(user) do
    user
    |> Panic.Generators.network()
    |> pick()
  end

  def network_with_models(user) do
    user
    |> Panic.Generators.network_with_models()
    |> pick()
  end
end

defmodule PanicWeb.Helpers do
  @moduledoc false
  def create_and_sign_in_user(%{conn: conn}) do
    password = "abcd1234"

    user = Panic.Fixtures.user(password)

    # Use real API tokens if they're available (for api_required tests)
    user =
      if System.get_env("OPENAI_API_KEY") && System.get_env("REPLICATE_API_KEY") do
        Panic.Generators.set_real_api_tokens!(user)
      else
        Panic.Generators.set_all_tokens(user)
      end

    strategy = AshAuthentication.Info.strategy!(Panic.Accounts.User, :password)

    {:ok, user} =
      AshAuthentication.Strategy.action(strategy, :sign_in, %{
        email: user.email,
        password: password
      })

    %{
      conn:
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(user),
      user: user
    }
  end
end

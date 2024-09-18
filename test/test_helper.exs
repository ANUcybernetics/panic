ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Panic.Repo, :manual)

defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  alias Panic.Accounts.User
  alias Panic.Engine.Network

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
    :panic
    |> Application.get_env(:api_tokens)
    |> Enum.map(fn {name, value} ->
      Panic.Accounts.set_token!(user, name, value, actor: user)
    end)
    |> List.last()
  end

  def user_with_tokens do
    gen all(user <- user()) do
      user = set_all_tokens(user)
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
        |> Enum.map(fn %Panic.Model{id: id} -> id end)

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

    user =
      password
      |> Panic.Fixtures.user()
      |> Panic.Generators.set_all_tokens()

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

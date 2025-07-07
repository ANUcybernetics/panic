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

  def user_with_real_tokens(password) do
    password
    |> StreamData.constant()
    |> Panic.Generators.user_with_real_tokens()
    |> pick()
  end

  def user_with_real_tokens do
    pick(Panic.Generators.user_with_real_tokens())
  end

  def network(user) do
    user
    |> Panic.Generators.network()
    |> pick()
  end

  def network_with_dummy_models(user) do
    user
    |> Panic.Generators.network_with_dummy_models()
    |> pick()
  end

  def network_with_real_models(user) do
    user
    |> Panic.Generators.network_with_real_models()
    |> pick()
  end

  def user_with_vestaboard_tokens do
    user = user()
    
    # Create API token with vestaboard tokens
    {:ok, api_token} = 
      Ash.create(
        Panic.Accounts.APIToken,
        %{
          name: "Test tokens with Vestaboard",
          openai_token: "test_openai_token",
          vestaboard_panic_1_token: "test_vestaboard_1",
          vestaboard_panic_2_token: "test_vestaboard_2",
          vestaboard_panic_3_token: "test_vestaboard_3",
          vestaboard_panic_4_token: "test_vestaboard_4"
        },
        authorize?: false
      )
    
    # Associate with user
    {:ok, _} =
      Ash.create(
        Panic.Accounts.UserAPIToken,
        %{
          user_id: user.id,
          api_token_id: api_token.id
        },
        authorize?: false
      )
    
    # Reload user with tokens
    Ash.load!(user, :api_tokens, authorize?: false)
  end
end

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

  @doc "Sets keys on the app's platform credentials (blank keys are left as they are)."
  def set_credentials(keys) do
    [authorize?: false]
    |> Panic.Accounts.get_platform_credentials!()
    |> Panic.Accounts.update_platform_credentials!(Map.new(keys), authorize?: false)
  end

  def vestaboard_credentials do
    set_credentials(
      vestaboard_panic_1_token: "test_vestaboard_1",
      vestaboard_panic_2_token: "test_vestaboard_2",
      vestaboard_panic_3_token: "test_vestaboard_3",
      vestaboard_panic_4_token: "test_vestaboard_4"
    )
  end
end

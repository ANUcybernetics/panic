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
end
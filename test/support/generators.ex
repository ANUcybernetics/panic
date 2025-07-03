defmodule Panic.Generators do
  @moduledoc """
  StreamData generators for Panic resources.
  """
  use ExUnitProperties

  alias Panic.Accounts.User
  alias Panic.Engine.Invocation
  alias Panic.Engine.Network
  alias Panic.Platforms.Dummy

  def ascii_sentence do
    :ascii
    |> string(min_length: 1)
    |> map(&String.trim/1)
    |> filter(&(String.length(&1) > 0))
  end

  def model(filters \\ []) do
    # Get all models matching the filters
    all_matching = Panic.Model.all(filters)

    # Get dummy models matching the filters
    dummy_matching = Enum.filter(all_matching, &(&1.platform == Dummy))

    # If we have at least 3 dummy models matching the filters, use only dummy models
    # Otherwise, use all models to avoid filter issues
    models_to_use =
      if length(dummy_matching) >= 3 do
        dummy_matching
      else
        all_matching
      end

    member_of(models_to_use)
  end

  def real_model(filters \\ []) do
    filters
    |> Panic.Model.all()
    |> member_of()
    |> filter(fn model -> model.platform != Dummy end)
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

  def user_with_real_tokens(password_generator \\ password()) do
    gen all(user <- user(password_generator)) do
      # Read API keys from environment variables
      openai_key = System.get_env("OPENAI_API_KEY")
      replicate_key = System.get_env("REPLICATE_API_KEY")
      gemini_key = System.get_env("GOOGLE_AI_STUDIO_TOKEN")

      # For apikeys tests, fail if keys are not present
      if openai_key == nil || replicate_key == nil || gemini_key == nil do
        raise "API keys required for this test. Set OPENAI_API_KEY, REPLICATE_API_KEY, and GOOGLE_AI_STUDIO_TOKEN environment variables."
      end

      # Create an APIToken with real tokens
      {:ok, api_token} =
        Ash.create(
          Panic.Accounts.APIToken,
          %{
            name: "Test Token with Real Keys",
            openai_token: openai_key,
            replicate_token: replicate_key,
            gemini_token: gemini_key
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

      # Return user with loaded tokens
      Ash.load!(user, :api_tokens, authorize?: false)
    end
  end

  def network(user) do
    gen all(input <- Ash.Generator.action_input(Network, :create)) do
      # Override lockout_seconds to 1 for tests
      input_with_lockout = Map.put(input, :lockout_seconds, 1)

      Network
      |> Ash.Changeset.for_create(:create, input_with_lockout, actor: user)
      |> Ash.create!()
    end
  end

  def network_with_dummy_models(user) do
    gen all(network <- network(user), length <- integer(1..5)) do
      # Create a simple chain of dummy models (flat list – vestaboards removed)
      model_ids =
        case length do
          1 -> ["dummy-t2t"]
          2 -> ["dummy-t2i", "dummy-i2t"]
          3 -> ["dummy-t2i", "dummy-i2i", "dummy-i2t"]
          4 -> ["dummy-t2a", "dummy-a2i", "dummy-i2i", "dummy-i2t"]
          _ -> ["dummy-t2i", "dummy-i2a", "dummy-a2i", "dummy-i2i", "dummy-i2t"]
        end

      Panic.Engine.update_models!(network, model_ids, actor: user)
    end
  end

  def network_with_real_models(user) do
    gen all(network <- network(user), length <- integer(1..10)) do
      model_ids =
        :text
        |> Stream.unfold(fn input_type ->
          next_model = [input_type: input_type] |> real_model() |> pick()
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
      Invocation
      |> Ash.Changeset.for_create(:prepare_first, %{input: input, network: network}, actor: user)
      |> Ash.create!()
    end
  end
end

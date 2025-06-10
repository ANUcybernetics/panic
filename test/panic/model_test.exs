defmodule Panic.ModelTest do
  use Panic.DataCase
  use ExUnitProperties

  alias Panic.Engine.Invocation
  alias Panic.Model

  @moduletag timeout: 300_000

  describe "model generators" do
    property "generate models with correct attributes" do
      check all(
              text_input_model <- Panic.Generators.model(input_type: :text),
              image_ouput_model <- Panic.Generators.model(output_type: :image),
              replicate_model <- Panic.Generators.real_model(platform: Panic.Platforms.Replicate)
            ) do
        assert %Panic.Model{input_type: :text} = text_input_model
        assert %Panic.Model{output_type: :image} = image_ouput_model
        assert %Panic.Model{platform: Panic.Platforms.Replicate} = replicate_model
      end
    end

    property "filter models by input type" do
      check all(
              input_type <- one_of([:text, :image]),
              model <- Panic.Generators.model(input_type: input_type)
            ) do
        assert model.input_type == input_type
      end
    end
  end

  describe "all platforms" do
    test "have models with unique ids" do
      # This includes all models: real platforms (OpenAI, Replicate, etc.) and dummy models
      model_ids =
        Enum.map(Model.all(), fn %Panic.Model{id: id} -> id end)

      unique_ids = Enum.uniq(model_ids)

      assert length(model_ids) == length(unique_ids), "all model IDs should be unique"
    end
  end

  describe "Replicate platform" do
    alias Panic.Platforms.Replicate

    @describetag api_required: true
    @describetag timeout: to_timeout(minute: 10)

    test "can list latest model version for all models" do
      user = Panic.Fixtures.user_with_real_tokens()
      models = Model.all(platform: Replicate)

      for model <- models do
        assert {:ok, version} = Replicate.get_latest_model_version(model, user.replicate_token)
        assert String.match?(version, ~r/^[a-f0-9]{64}$/)
      end
    end

    test "can generate a stable diffusion image" do
      user = Panic.Fixtures.user_with_real_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("flux-schnell")

      {:ok, img_url} =
        invoke_fn.(model, "I could eat a peach for hours.", user.replicate_token)

      assert String.match?(img_url, ~r|^https://.*$|)
    end

    test "BLIP2 captioner is sufficiently expressive" do
      user = Panic.Fixtures.user_with_real_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("blip-2")
      # TODO the rate limit here is pretty low, so maybe switch to a static image somewhere?
      input_img = "https://picsum.photos/400/225/"

      {:ok, caption} =
        invoke_fn.(model, input_img, user.replicate_token)

      # not a 100% reliable test, but we're going for descriptive captions here
      assert String.length(caption) > 10
    end

    @tag skip: true
    @tag api_required: true
    test "can successfully invoke all Replicate models" do
      user = Panic.Fixtures.user_with_real_tokens()
      models = Model.all(platform: Replicate)

      tasks =
        for %Model{id: id, invoke: invoke_fn} = model <- models do
          Task.async(fn ->
            input = test_input(model)
            result = invoke_fn.(model, input, user.replicate_token)

            case result do
              {:ok, output} ->
                IO.puts("#{id}: Input: #{inspect(input)}, Output: #{inspect(output)}")

              _ ->
                :pass
            end

            {id, result}
          end)
        end

      results = Task.await_many(tasks, :infinity)

      failed_models =
        results
        |> Enum.filter(fn {_, result} ->
          case result do
            {:error, _} -> true
            _ -> false
          end
        end)
        |> Enum.map(fn {id, _} -> id end)

      if length(failed_models) > 0 do
        IO.puts("Failed models: #{Enum.join(failed_models, ", ")}")
      end

      for {_, result} <- results do
        case result do
          {:ok, output} ->
            assert String.match?(output, ~r/\S/)

          {:error, _} ->
            flunk("Some models failed to invoke")
        end
      end
    end

    test "can successfully invoke a specific model" do
      user = Panic.Fixtures.user_with_real_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("florence-2-large")
      input = test_input(model)

      assert {:ok, output} = invoke_fn.(model, input, user.replicate_token)
      assert String.match?(output, ~r/\S/)
    end
  end

  describe "OpenAI platform" do
    alias Panic.Platforms.OpenAI

    @describetag api_required: true

    test "generates the right* answer for all models" do
      # models for which we have canned responses
      user = Panic.Fixtures.user_with_real_tokens()
      models = Model.all(platform: OpenAI)

      for model <- models do
        assert {:ok, output} =
                 OpenAI.invoke(
                   model,
                   "Respond with just the word 'bananaphone'. Do not include any other content (even punctuation).",
                   user.openai_token
                 )

        assert output == "bananaphone"
      end
    end
  end

  describe "Gemini platform" do
    @describetag api_required: true

    test "can successfully invoke the audio description model" do
      # user = Panic.Fixtures.user_with_tokens()
      %Model{invoke: invoke_fn} = model = Model.by_id!("gemini-audio-description")
      input = test_input(model)

      assert {:ok, output} = invoke_fn.(model, input, System.get_env("GOOGLE_AI_STUDIO_TOKEN"))
      assert String.match?(output, ~r/\S/)
    end

    test "run a Gemini audio description model in a network" do
      user = Panic.Fixtures.user_with_real_tokens()

      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["magnet"], ["gemini-audio-description"]], actor: user)

      input = "solo piano etude"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      next =
        first
        |> Panic.Engine.prepare_next!(actor: user)
        |> Panic.Engine.invoke!(actor: user)

      assert %Invocation{output: output} = next
      assert String.match?(output, ~r/\S/)
    end
  end

  describe "Dummy platform" do
    alias Panic.Platforms.Dummy

    test "all dummy models have correct input/output type combinations" do
      dummy_models = Model.all(platform: Dummy)

      expected_combinations = [
        {"dummy-t2t", :text, :text},
        {"dummy-t2i", :text, :image},
        {"dummy-t2a", :text, :audio},
        {"dummy-i2t", :image, :text},
        {"dummy-i2i", :image, :image},
        {"dummy-i2a", :image, :audio},
        {"dummy-a2t", :audio, :text},
        {"dummy-a2i", :audio, :image},
        {"dummy-a2a", :audio, :audio}
      ]

      for {id, input_type, output_type} <- expected_combinations do
        model = Enum.find(dummy_models, &(&1.id == id))
        assert model != nil, "Model #{id} should exist"
        assert model.input_type == input_type, "Model #{id} should have input_type #{input_type}"
        assert model.output_type == output_type, "Model #{id} should have output_type #{output_type}"
      end
    end

    test "dummy models produce deterministic outputs" do
      dummy_models = Model.all(platform: Dummy)

      for %Model{invoke: invoke_fn} = model <- dummy_models do
        input = test_input(model)

        # Invoke the model twice with the same input
        {:ok, output1} = invoke_fn.(model, input, nil)
        {:ok, output2} = invoke_fn.(model, input, nil)

        # Outputs should be identical
        assert output1 == output2, "Model #{model.id} should produce deterministic output"

        # Outputs should contain expected markers
        case model.output_type do
          :text -> assert String.contains?(output1, "DUMMY_")
          :image -> assert String.starts_with?(output1, "https://dummy-images.test/")
          :audio -> assert String.starts_with?(output1, "https://dummy-audio.test/")
        end
      end
    end

    test "dummy models can be used in a network" do
      user = Panic.Fixtures.user()

      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["dummy-t2i"], ["dummy-i2t"]], actor: user)

      input = "test prompt"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      assert String.starts_with?(first.output, "https://dummy-images.test/")

      next =
        first
        |> Panic.Engine.prepare_next!(actor: user)
        |> Panic.Engine.invoke!(actor: user)

      assert String.starts_with?(next.output, "DUMMY_CAPTION:")
    end
  end

  defp test_input(%Model{input_type: :text}), do: "a shiny red apple"

  defp test_input(%Model{input_type: :image}),
    do: "https://fly.storage.tigris.dev/panic-invocation-outputs/nsfw-placeholder.webp"

  defp test_input(%Model{input_type: :audio}),
    do: "https://fly.storage.tigris.dev/panic-invocation-outputs/test-audio.ogg"

  describe "Invocation integration with API calls" do
    @describetag api_required: true

    test "can produce output with real API models" do
      user = Panic.Fixtures.user_with_real_tokens()
      # a pretty simple network, should be fast & cheap
      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["flux-schnell"], ["blip-2"]], actor: user)

      input = "can you tell me a story?"

      invocation =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      refute invocation.output == nil
      assert invocation.state == :completed
    end

    test "creates a next invocation with the right run number and sequence with real models" do
      user = Panic.Fixtures.user_with_real_tokens()
      network = Panic.Fixtures.network_with_real_models(user)
      input = "can you tell me a story?"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      next = Panic.Engine.prepare_next!(first, actor: user)
      assert first.run_number == next.run_number
      assert first.output == next.input
      assert first.sequence_number + 1 == next.sequence_number
    end

    test "can make a 'run' with invoke! and prepare_next! which maintains io consistency and ordering with real models" do
      run_length = 4
      user = Panic.Fixtures.user_with_real_tokens()
      network = Panic.Fixtures.network_with_real_models(user)
      input = "can you tell me a story?"

      first =
        network
        |> Panic.Engine.prepare_first!(input, actor: user)
        |> Panic.Engine.invoke!(actor: user)

      first
      |> Stream.iterate(fn inv ->
        inv
        |> Panic.Engine.invoke!(actor: user)
        |> Panic.Engine.prepare_next!(actor: user)
      end)
      |> Stream.take(run_length)
      |> Stream.run()

      invocations =
        Panic.Engine.list_run!(network.id, first.run_number, actor: user)

      [second_last_in_current_run, last_in_current_run] =
        Panic.Engine.current_run!(network.id, 2, actor: user)

      assert second_last_in_current_run.sequence_number == last_in_current_run.sequence_number - 1
      assert second_last_in_current_run.run_number == last_in_current_run.run_number

      # check outputs match inputs
      invocations
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a.output == b.input
      end)

      # check the right number of invocations generated, and returned in the right order
      assert Enum.count(invocations) == run_length
      sequence_numbers = Enum.map(invocations, & &1.sequence_number)
      assert sequence_numbers = Enum.sort(sequence_numbers, :asc)

      # check the most recent invocation action works
      most_recent = Panic.Engine.most_recent!(network.id, actor: user)
      assert most_recent.sequence_number == Enum.max(sequence_numbers)
    end
  end

  describe "Gemini token integration" do
    @describetag api_required: true

    test "user with gemini token can create invocation with gemini model" do
      user = Panic.Fixtures.user()

      # Set a gemini token for the user
      user_with_token = Panic.Accounts.set_token!(user, :gemini_token, "test_gemini_token", actor: user)

      # Create a network with a dummy text-to-audio model followed by gemini model
      # This ensures compatible input/output types: text -> audio -> text
      network =
        user_with_token
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["dummy-t2a"], ["gemini-audio-description"]], actor: user_with_token)

      input = "generate some audio"

      # Create and prepare the invocation
      invocation = Panic.Engine.prepare_first!(network, input, actor: user_with_token)

      # Verify the invocation was created successfully
      assert invocation.network_id == network.id
      assert invocation.input == input
      assert invocation.model == ["dummy-t2a"]
    end

    test "user without gemini token gets error when invoking gemini model" do
      alias Ash.Error.Invalid

      user = Panic.Fixtures.user()

      # Create a network with a dummy text-to-audio model followed by gemini model
      network =
        user
        |> Panic.Fixtures.network()
        |> Panic.Engine.update_models!([["dummy-t2a"], ["gemini-audio-description"]], actor: user)

      input = "generate some audio"

      # Create first invocation and invoke it (dummy model should work)
      first_invocation = Panic.Engine.prepare_first!(network, input, actor: user)
      first_invocation = Panic.Engine.invoke!(first_invocation, actor: user)

      # Prepare next invocation (which will use gemini model)
      second_invocation = Panic.Engine.prepare_next!(first_invocation, actor: user)

      # Try to invoke gemini model without gemini token - should fail
      assert_raise Invalid, fn ->
        Panic.Engine.invoke!(second_invocation, actor: user)
      end
    end
  end
end

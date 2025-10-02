defmodule Panic.Validations.ModelIOConnectionsTest do
  use Panic.DataCase, async: false

  alias Panic.Model
  alias Panic.Validations.ModelIOConnections

  describe "network_runnable?/1" do
    test "accepts empty network as invalid" do
      assert {:error, "network must contain at least one model"} =
               ModelIOConnections.network_runnable?([])
    end

    test "accepts single text->text model forming valid cycle" do
      # Single text->text model forms a valid cycle
      assert :ok = ModelIOConnections.network_runnable?(["gpt-5-chat"])
    end

    test "accepts multiple text->text models forming valid cycle" do
      # All text->text models form a valid cycle
      assert :ok =
               ModelIOConnections.network_runnable?([
                 "gpt-5-chat",
                 "dummy-t2t",
                 "gpt-5-chat"
               ])
    end

    test "rejects models with incompatible sequential I/O types" do
      # text->image followed by text->text is invalid
      # (image output doesn't match text input)
      result =
        ModelIOConnections.network_runnable?([
          # text -> image
          "stable-diffusion",
          # text -> text (needs text input, gets image)
          "gpt-5-chat"
        ])

      assert {:error, _message} = result
    end

    test "rejects network that doesn't form a valid cycle" do
      # Find models that create an invalid cycle
      # text -> image
      stable_diffusion = Model.by_id!("stable-diffusion")

      # Find an image->audio model if it exists, or image->image
      image_models = Model.all(input_type: :image)
      non_text_output = Enum.find(image_models, fn m -> m.output_type != :text end)

      if non_text_output do
        result =
          ModelIOConnections.network_runnable?([
            stable_diffusion.id,
            non_text_output.id
          ])

        assert {:error, _message} = result
      end
    end

    test "accepts text->image->text cycle (valid)" do
      # Find text->image model
      text_to_image = [input_type: :text, output_type: :image] |> Model.all() |> List.first()
      # Find image->text model
      image_to_text = [input_type: :image, output_type: :text] |> Model.all() |> List.first()

      if text_to_image && image_to_text do
        # This forms a valid cycle: text -> image -> text (loops back to text)
        assert :ok =
                 ModelIOConnections.network_runnable?([
                   text_to_image.id,
                   image_to_text.id
                 ])
      end
    end

    test "accepts text->audio->text cycle (valid)" do
      # Find text->audio model
      text_to_audio = [input_type: :text, output_type: :audio] |> Model.all() |> List.first()
      # Find audio->text model  
      audio_to_text = [input_type: :audio, output_type: :text] |> Model.all() |> List.first()

      if text_to_audio && audio_to_text do
        # This forms a valid cycle: text -> audio -> text (loops back to text)
        assert :ok =
                 ModelIOConnections.network_runnable?([
                   text_to_audio.id,
                   audio_to_text.id
                 ])
      end
    end

    test "rejects text->image->audio cycle (invalid)" do
      # Find the models
      text_to_image = [input_type: :text, output_type: :image] |> Model.all() |> List.first()
      image_to_audio = [input_type: :image, output_type: :audio] |> Model.all() |> List.first()

      if text_to_image && image_to_audio do
        # This is invalid: text -> image -> audio
        # The cycle doesn't close because audio != text
        result =
          ModelIOConnections.network_runnable?([
            text_to_image.id,
            image_to_audio.id
          ])

        assert {:error, _message} = result
      end
    end

    test "handles complex valid cycles" do
      # Build a complex but valid cycle if we have the models
      text_models = [input_type: :text, output_type: :text] |> Model.all() |> Enum.take(5)

      if length(text_models) >= 3 do
        model_ids = text_models |> Enum.map(& &1.id) |> Enum.take(3)
        assert :ok = ModelIOConnections.network_runnable?(model_ids)
      end
    end

    test "provides clear error messages for multiple violations" do
      # Create a network with multiple problems
      # text -> image
      text_to_image = Model.by_id!("stable-diffusion")
      # text -> text
      text_to_text = Model.by_id!("gpt-5-chat")

      result =
        ModelIOConnections.network_runnable?([
          text_to_image.id,
          text_to_text.id,
          # Another text->image
          text_to_image.id
        ])

      assert {:error, _message} = result
    end

    test "validates initial text input requirement" do
      # The first model must accept text input (since user provides text)
      # This is enforced by the prepended sentinel check

      # Find a non-text input model if available
      non_text_input = Enum.find(Model.all(), fn m -> m.input_type != :text end)

      if non_text_input do
        # Even if it could form a cycle with another model,
        # it's invalid if the first model doesn't accept text
        result = ModelIOConnections.network_runnable?([non_text_input.id])

        assert {:error, _message} = result
      end
    end
  end

  describe "validate/3 changeset integration" do
    test "integrates with Ash changeset validation" do
      user = Panic.Fixtures.user()
      network = Panic.Fixtures.network(user)

      # Try to update with invalid model combination
      result =
        Ash.update(network,
          action: :update_models,
          # Invalid: image -> text input mismatch
          params: %{models: ["stable-diffusion", "gpt-5-chat"]},
          actor: user
        )

      # Should fail validation
      assert {:error, %Ash.Error.Invalid{}} = result
    end
  end

  describe "edge cases" do
    test "handles model lookup failures gracefully" do
      # Test with invalid model ID
      # Should return error message when model doesn't exist
      assert {:error, message} = ModelIOConnections.network_runnable?(["invalid-model-id"])
      assert message =~ "Network contains models that no longer exist"
      assert message =~ "invalid-model-id"
    end

    test "validates all text->text models properly" do
      # Get all text->text models
      text_models = Model.all(input_type: :text, output_type: :text)

      # Any combination of text->text models should form a valid cycle
      for model <- Enum.take(text_models, 5) do
        assert :ok = ModelIOConnections.network_runnable?([model.id])

        # Two of the same model should also work
        assert :ok = ModelIOConnections.network_runnable?([model.id, model.id])
      end
    end

    test "handles single model cycles correctly" do
      # Test each I/O type combination for single models
      for model <- Enum.take(Model.all(), 10) do
        result = ModelIOConnections.network_runnable?([model.id])

        if model.input_type == model.output_type do
          # Models with same I/O type can form single-model cycles
          assert result == :ok,
                 "Model #{model.id} with #{model.input_type}->#{model.output_type} should form valid cycle"
        else
          # Models with different I/O types cannot form single-model cycles
          assert {:error, _} = result
        end
      end
    end
  end
end

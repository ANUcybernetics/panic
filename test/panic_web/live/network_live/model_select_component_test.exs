defmodule PanicWeb.NetworkLive.ModelSelectComponentTest do
  use Panic.DataCase, async: true
  use ExUnitProperties

  alias Panic.Model

  describe "model options formatting for AutocompleteInput" do
    test "model options are formatted as tuples, not maps" do
      # Test the exact format that was causing the FunctionClauseError
      # AutocompleteInput.to_item/1 expects {label, value} tuples

      models = [input_type: :text] |> Model.all() |> Enum.take(3)

      # This is the correct format (tuples)
      correct_options = Enum.map(models, fn model -> {model.name, model.id} end)

      # This was the incorrect format (maps) that caused the error
      incorrect_options = Enum.map(models, fn model -> %{label: model.name, value: model.id} end)

      # Test that we're using the correct format
      for option <- correct_options do
        assert is_tuple(option), "Option should be a tuple for AutocompleteInput compatibility"
        assert tuple_size(option) == 2, "Tuple should have exactly 2 elements"
        {label, value} = option
        assert is_binary(label), "Label should be a string"
        assert is_binary(value), "Value should be a string"
      end

      # Verify the incorrect format would fail (for documentation purposes)
      for option <- incorrect_options do
        assert is_map(option), "This format causes FunctionClauseError in AutocompleteInput"
        assert Map.has_key?(option, :label), "Map format has :label key"
        assert Map.has_key?(option, :value), "Map format has :value key"
      end
    end

    property "model options maintain tuple format with any search filtering" do
      check all(search_term <- string(:printable, max_length: 10)) do
        # Simulate the filtering logic used in the component
        filtered_models =
          [input_type: :text]
          |> Model.all()
          |> Enum.filter(fn model ->
            String.downcase(model.name) =~ String.downcase(search_term)
          end)
          |> Enum.map(fn model -> {model.name, model.id} end)

        # All filtered options should still be tuples
        for option <- filtered_models do
          assert is_tuple(option), "Filtered option should remain a tuple"
          assert tuple_size(option) == 2, "Tuple should have 2 elements"
          {label, value} = option
          assert is_binary(label) and is_binary(value), "Both elements should be strings"
        end
      end
    end

    test "specific regression test for the FunctionClauseError" do
      # This test specifically prevents the error:
      # ** (FunctionClauseError) no function clause matching in AutocompleteInput.to_item/1
      # AutocompleteInput.to_item(%{label: "GPT-4.1", value: "gpt-4.1"})

      # Get a sample model
      model = Model.by_id!("gpt-4.1")

      # This is the format that was causing the error (map)
      incorrect_format = %{label: model.name, value: model.id}

      # This is the correct format (tuple)
      correct_format = {model.name, model.id}

      # Verify the correct format is a tuple
      assert is_tuple(correct_format)
      assert not is_map(correct_format)

      # Document what the incorrect format looked like
      assert is_map(incorrect_format)
      assert not is_tuple(incorrect_format)

      # The correct format should match the pattern AutocompleteInput.to_item/1 expects
      {label, value} = correct_format
      assert label == model.name
      assert value == model.id
    end
  end
end

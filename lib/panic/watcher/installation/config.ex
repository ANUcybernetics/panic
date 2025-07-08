defmodule Panic.Watcher.Installation.Config do
  @moduledoc """
  Embedded schema representing a display configuration for an Installation.

  A config defines how invocations should be displayed. There are three types:

  * `:grid` - Displays invocations in a grid layout with specified rows and columns
  * `:single` - Shows a single invocation based on stride and offset
  * `:vestaboard` - Similar to single but for Vestaboard displays with a specific vestaboard name

  All configs require a unique name within an installation for URL routing.

  ## Examples

      # Grid config
      %Config{type: :grid, name: "main-grid", rows: 2, columns: 3}

      # Single config showing every 3rd invocation starting from offset 1
      %Config{type: :single, name: "spotlight", stride: 3, offset: 1}

      # Vestaboard config showing every 3rd invocation and initial prompt
      %Config{type: :vestaboard, name: "board-1", stride: 3, offset: 0, vestaboard_name: :panic_1, initial_prompt: true}
  """

  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [:grid, :single, :vestaboard]
    end

    # Name for all config types - human-readable, alphanumeric + hyphens
    attribute :name, :string do
      allow_nil? false
      constraints match: ~r/^[a-zA-Z0-9-]+$/
    end

    # Grid-specific attributes
    attribute :rows, :integer do
      constraints min: 1
    end

    attribute :columns, :integer do
      constraints min: 1
    end

    # Single/Vestaboard-specific attributes
    attribute :stride, :integer do
      constraints min: 1
    end

    attribute :offset, :integer do
      constraints min: 0
    end

    # Single/Vestaboard-specific attributes
    attribute :show_invoking, :boolean do
      default false
    end

    # Vestaboard-specific attributes
    attribute :vestaboard_name, :atom do
      constraints one_of: [:panic_1, :panic_2, :panic_3, :panic_4]
    end

    attribute :initial_prompt, :boolean do
      default false
    end
  end

  actions do
    create :create do
      primary? true
      accept [:type, :name, :rows, :columns, :stride, :offset, :show_invoking, :vestaboard_name, :initial_prompt]
    end

    update :update do
      primary? true
      accept [:type, :name, :rows, :columns, :stride, :offset, :show_invoking, :vestaboard_name, :initial_prompt]
    end
  end

  validations do
    validate present([:type, :name]), message: "type and name are required"

    # Grid validations
    validate present([:rows, :columns]),
      where: attribute_equals(:type, :grid),
      message: "rows and columns are required for grid type"

    validate absent([:stride, :offset, :vestaboard_name]),
      where: attribute_equals(:type, :grid),
      message: "stride, offset, and vestaboard_name are not allowed for grid type"

    # Single validations
    validate present([:stride, :offset]),
      where: attribute_equals(:type, :single),
      message: "stride and offset are required for single type"

    validate absent([:rows, :columns, :vestaboard_name]),
      where: attribute_equals(:type, :single),
      message: "rows, columns, and vestaboard_name are not allowed for single type"

    # Vestaboard validations
    validate present([:stride, :offset, :vestaboard_name]),
      where: attribute_equals(:type, :vestaboard),
      message: "stride, offset, and vestaboard_name are required for vestaboard type"

    validate absent([:rows, :columns]),
      where: attribute_equals(:type, :vestaboard),
      message: "rows and columns are not allowed for vestaboard type"

    validate attribute_equals(:initial_prompt, false),
      where: attribute_does_not_equal(:type, :vestaboard),
      message: "initial_prompt can only be true for vestaboard type"

    validate attribute_equals(:show_invoking, false),
      where: attribute_equals(:type, :grid),
      message: "show_invoking can only be set for single and vestaboard types"

    # Ensure offset is less than stride for single and vestaboard types
    validate Panic.Watcher.Validations.OffsetLessThanStride
  end
end
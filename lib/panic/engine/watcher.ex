defmodule Panic.Engine.Installation.Watcher do
  @moduledoc """
  Embedded schema representing a watcher configuration for an Installation.

  A watcher defines how invocations should be displayed. There are three types:

  * `:grid` - Displays invocations in a grid layout with specified rows and columns
  * `:single` - Shows a single invocation based on stride and offset
  * `:vestaboard` - Similar to single but for Vestaboard displays with a specific name

  ## Examples

      # Grid watcher
      %Watcher{type: :grid, rows: 2, columns: 3}

      # Single watcher showing every 3rd invocation starting from offset 1
      %Watcher{type: :single, stride: 3, offset: 1}

      # Vestaboard watcher
      %Watcher{type: :vestaboard, stride: 1, offset: 0, name: :panic_1}
  """

  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [:grid, :single, :vestaboard]
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

    # Vestaboard-specific attributes
    attribute :name, :atom do
      constraints one_of: [:panic_1, :panic_2, :panic_3, :panic_4]
    end
  end

  actions do
    create :create do
      primary? true
      accept [:type, :rows, :columns, :stride, :offset, :name]
    end
  end

  validations do
    validate present([:type]), message: "type is required"

    # Grid validations
    validate present([:rows, :columns]),
      where: attribute_equals(:type, :grid),
      message: "rows and columns are required for grid type"

    validate absent([:stride, :offset, :name]),
      where: attribute_equals(:type, :grid),
      message: "stride, offset, and name are not allowed for grid type"

    # Single validations
    validate present([:stride, :offset]),
      where: attribute_equals(:type, :single),
      message: "stride and offset are required for single type"

    validate absent([:rows, :columns, :name]),
      where: attribute_equals(:type, :single),
      message: "rows, columns, and name are not allowed for single type"

    # Vestaboard validations
    validate present([:stride, :offset, :name]),
      where: attribute_equals(:type, :vestaboard),
      message: "stride, offset, and name are required for vestaboard type"

    validate absent([:rows, :columns]),
      where: attribute_equals(:type, :vestaboard),
      message: "rows and columns are not allowed for vestaboard type"

    # Ensure offset is less than stride for single and vestaboard types
    validate Panic.Engine.Validations.OffsetLessThanStride
  end
end

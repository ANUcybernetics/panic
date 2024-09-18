defmodule PanicWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.Components

  override Components.Password do
    set :register_toggle_text, nil
    set :reset_toggle_text, nil
  end
end

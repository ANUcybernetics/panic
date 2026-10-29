defmodule PanicWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :text, "PANIC!"
    set :text_class, "text-4xl font-bold text-primary-content"
  end

  override Components.Password do
    set :register_toggle_text, nil
    set :reset_toggle_text, nil
  end

  # the API key strategy has no form, so there's nothing to put "or" between
  override Components.HorizontalRule do
    set :root_class, "hidden"
  end
end

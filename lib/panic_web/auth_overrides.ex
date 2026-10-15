defmodule PanicWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :text, "PANIC!"
    set :text_class, "text-4xl font-bold text-purple-300"
  end

  override Components.Password do
    set :register_toggle_text, nil
    set :reset_toggle_text, nil
  end

  # match CoreComponents.input/1 and button/1
  override Components.Password.Input do
    set :label_class, "block text-sm font-semibold leading-6 text-purple-400"

    set :input_class,
        "mt-2 block w-full rounded-lg text-purple-300 bg-zinc-800 border-zinc-700 focus:border-purple-500 focus:ring-2 focus:ring-purple-300 sm:text-sm sm:leading-6"

    set :input_class_with_error,
        "mt-2 block w-full rounded-lg text-purple-300 bg-zinc-800 border-rose-400 focus:border-rose-400 sm:text-sm sm:leading-6"

    set :submit_class,
        "mt-6 w-full rounded-lg bg-purple-900 hover:bg-purple-600 py-2 px-3 text-sm font-semibold leading-6 text-purple-300"
  end

  # the API key strategy has no form, so there's nothing to put "or" between
  override Components.HorizontalRule do
    set :root_class, "hidden"
  end
end

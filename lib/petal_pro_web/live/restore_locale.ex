defmodule PetalProWeb.RestoreLocale do
  def on_mount(:default, _params, %{"locale" => locale} = _session, socket) do
    Gettext.put_locale(PetalProWeb.Gettext, locale)
    {:cont, socket}
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}
end

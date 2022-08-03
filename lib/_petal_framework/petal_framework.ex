defmodule PetalFramework do
  defmacro __using__(_) do
    quote do
      import PetalFramework.Components.{
        Notification,
        PageComponents,
        UserDropdownMenu,
        ColorSchemeSwitch,
        LanguageSelect,
        SocialButton,
        AuthLayout,
        Navbar,
        SidebarLayout,
        StackedLayout,
        Markdown
      }
    end
  end
end

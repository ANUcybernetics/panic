defmodule PetalFramework.Components.SocialButton do
  use Phoenix.Component
  import PetalComponents.Link
  import PetalComponents.Class

  # prop class, :string
  # prop color, :string, options: ["primary", "secondary", "info", "success", "warning", "danger", "gray"]
  # prop link_type, :string, options: ["button", "a", "live_patch", "live_redirect"]
  # prop size, :string
  # prop to, :string
  def social_button(assigns) do
    assigns =
      assigns
      |> assign_new(:link_type, fn -> "a" end)
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:to, fn -> nil end)
      |> assign_new(:logo, fn -> "" end)
      |> assign_new(:variant, fn -> "solid" end)

    ~H"""
    <.link
      link_type={@link_type}
      to={@to}
      class={
        build_class([
          "text-sm border leading-5 px-4 py-2 font-medium rounded-md inline-flex gap-4 items-center justify-center",
          get_social_button_classes(%{logo: @logo, variant: @variant}),
          @class
        ])
      }
    >
      <%= if @logo == "google" do %>
        <svg class="w-5 h-5" viewBox="0 0 19 20" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path
            d="M18.9892 10.1871C18.9892 9.36767 18.9246 8.76973 18.7847 8.14966H9.68848V11.848H15.0277C14.9201 12.767 14.3388 14.1512 13.047 15.0812L13.0289 15.205L15.905 17.4969L16.1042 17.5173C17.9342 15.7789 18.9892 13.221 18.9892 10.1871Z"
            fill={if @variant == "solid", do: "#fff", else: "#4285F4"}
          >
          </path>
          <path
            d="M9.68813 19.9314C12.3039 19.9314 14.4999 19.0455 16.1039 17.5174L13.0467 15.0813C12.2286 15.6682 11.1306 16.0779 9.68813 16.0779C7.12612 16.0779 4.95165 14.3395 4.17651 11.9366L4.06289 11.9465L1.07231 14.3273L1.0332 14.4391C2.62638 17.6946 5.89889 19.9314 9.68813 19.9314Z"
            fill={if @variant == "solid", do: "#fff", else: "#34A853"}
          >
          </path>
          <path
            d="M4.17667 11.9366C3.97215 11.3165 3.85378 10.6521 3.85378 9.96562C3.85378 9.27905 3.97215 8.6147 4.16591 7.99463L4.1605 7.86257L1.13246 5.44363L1.03339 5.49211C0.37677 6.84302 0 8.36005 0 9.96562C0 11.5712 0.37677 13.0881 1.03339 14.4391L4.17667 11.9366Z"
            fill={if @variant == "solid", do: "#fff", else: "#FBBC05"}
          >
          </path>
          <path
            d="M9.68807 3.85336C11.5073 3.85336 12.7344 4.66168 13.4342 5.33718L16.1684 2.59107C14.4892 0.985496 12.3039 0 9.68807 0C5.89885 0 2.62637 2.23672 1.0332 5.49214L4.16573 7.99466C4.95162 5.59183 7.12608 3.85336 9.68807 3.85336Z"
            fill={if @variant == "solid", do: "#fff", else: "#EB4335"}
          >
          </path>
        </svg>
        <p>Continue with Google</p>
      <% end %>

      <%= if @logo == "github" do %>
        <svg
          class={
            "w-5 h-5 #{if @variant == "solid", do: "fill-white", else: "dark:fill-white fill-gray-800"}"
          }
          viewBox="0 0 21 20"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M10.1543 0C4.6293 0 0.154298 4.475 0.154298 10C0.153164 12.0993 0.813112 14.1456 2.04051 15.8487C3.26792 17.5517 5.00044 18.8251 6.9923 19.488C7.4923 19.575 7.6793 19.275 7.6793 19.012C7.6793 18.775 7.6663 17.988 7.6663 17.15C5.1543 17.613 4.5043 16.538 4.3043 15.975C4.1913 15.687 3.7043 14.8 3.2793 14.562C2.9293 14.375 2.4293 13.912 3.2663 13.9C4.0543 13.887 4.6163 14.625 4.8043 14.925C5.7043 16.437 7.1423 16.012 7.7163 15.75C7.8043 15.1 8.0663 14.663 8.3543 14.413C6.1293 14.163 3.8043 13.3 3.8043 9.475C3.8043 8.387 4.1913 7.488 4.8293 6.787C4.7293 6.537 4.3793 5.512 4.9293 4.137C4.9293 4.137 5.7663 3.875 7.6793 5.163C8.49336 4.93706 9.33447 4.82334 10.1793 4.825C11.0293 4.825 11.8793 4.937 12.6793 5.162C14.5913 3.862 15.4293 4.138 15.4293 4.138C15.9793 5.513 15.6293 6.538 15.5293 6.788C16.1663 7.488 16.5543 8.375 16.5543 9.475C16.5543 13.313 14.2173 14.163 11.9923 14.413C12.3543 14.725 12.6673 15.325 12.6673 16.263C12.6673 17.6 12.6543 18.675 12.6543 19.013C12.6543 19.275 12.8423 19.587 13.3423 19.487C15.3273 18.8168 17.0522 17.541 18.2742 15.8392C19.4962 14.1373 20.1537 12.0951 20.1543 10C20.1543 4.475 15.6793 0 10.1543 0Z">
          </path>
        </svg>
        <p>Continue with Github</p>
      <% end %>

      <%= if @logo == "facebook" do %>
        <svg
          class={"w-5 h-5 #{if @variant == "solid", do: "fill-white", else: "fill-[#1778F2]"}"}
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 320 512"
        >
          <path d="M279.1 288l14.22-92.66h-88.91v-60.13c0-25.35 12.42-50.06 52.24-50.06h40.42V6.26S260.4 0 225.4 0c-73.22 0-121.1 44.38-121.1 124.7v70.62H22.89V288h81.39v224h100.2V288z">
          </path>
        </svg>

        <p>Continue with Facebook</p>
      <% end %>

      <%= if @logo == "twitter" do %>
        <svg
          class={"w-5 h-5 #{if @variant == "solid", do: "fill-white", else: "fill-[#1da1f2]"}"}
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 512 512"
        >
          <path d="M459.4 151.7c.325 4.548 .325 9.097 .325 13.65 0 138.7-105.6 298.6-298.6 298.6-59.45 0-114.7-17.22-161.1-47.11 8.447 .974 16.57 1.299 25.34 1.299 49.06 0 94.21-16.57 130.3-44.83-46.13-.975-84.79-31.19-98.11-72.77 6.498 .974 12.99 1.624 19.82 1.624 9.421 0 18.84-1.3 27.61-3.573-48.08-9.747-84.14-51.98-84.14-102.1v-1.299c13.97 7.797 30.21 12.67 47.43 13.32-28.26-18.84-46.78-51.01-46.78-87.39 0-19.49 5.197-37.36 14.29-52.95 51.65 63.67 129.3 105.3 216.4 109.8-1.624-7.797-2.599-15.92-2.599-24.04 0-57.83 46.78-104.9 104.9-104.9 30.21 0 57.5 12.67 76.67 33.14 23.72-4.548 46.46-13.32 66.6-25.34-7.798 24.37-24.37 44.83-46.13 57.83 21.12-2.273 41.58-8.122 60.43-16.24-14.29 20.79-32.16 39.31-52.63 54.25z">
          </path>
        </svg>
        <p>Continue with Twitter</p>
      <% end %>

      <%= if @logo == "apple" do %>
        <svg
          class={
            "w-5 h-5 #{if @variant == "solid", do: "fill-white", else: "fill-[#050708] dark:fill-white"}"
          }
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 384 512"
        >
          <path
            fill="currentColor"
            d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"
          >
          </path>
        </svg>
        <p>Continue with Apple</p>
      <% end %>

      <%= if @logo == "linkedin" do %>
        <svg
          class={"w-5 h-5 #{if @variant == "solid", do: "fill-white", else: "fill-[#0B65C2]"}"}
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 5 1036 990"
        >
          <path d="M0 120c0-33.334 11.667-60.834 35-82.5C58.333 15.833 88.667 5 126 5c36.667 0 66.333 10.666 89 32 23.333 22 35 50.666 35 86 0 32-11.333 58.666-34 80-23.333 22-54 33-92 33h-1c-36.667 0-66.333-11-89-33S0 153.333 0 120zm13 875V327h222v668H13zm345 0h222V622c0-23.334 2.667-41.334 8-54 9.333-22.667 23.5-41.834 42.5-57.5 19-15.667 42.833-23.5 71.5-23.5 74.667 0 112 50.333 112 151v357h222V612c0-98.667-23.333-173.5-70-224.5S857.667 311 781 311c-86 0-153 37-201 111v2h-1l1-2v-95H358c1.333 21.333 2 87.666 2 199 0 111.333-.667 267.666-2 469z" />
        </svg>
        <p>Continue with LinkedIn</p>
      <% end %>
    </.link>
    """
  end

  defp get_social_button_classes(%{logo: _, variant: "outline"}),
    do:
      "text-gray-700 bg-white border-gray-300 hover:text-gray-900 hover:text-gray-900 hover:border-gray-400 hover:bg-gray-50 focus:outline-none focus:border-gray-400 focus:bg-gray-100 focus:text-gray-900 active:border-gray-400 active:bg-gray-200 active:text-black dark:text-gray-300 dark:focus:text-gray-100 dark:active:text-gray-100 dark:hover:text-gray-200 dark:bg-transparent dark:hover:bg-gray-800 dark:hover:border-gray-400 dark:border-gray-500 dark:focus:border-gray-300 dark:active:border-gray-300"

  defp get_social_button_classes(%{logo: "google", variant: "solid"}),
    do: "bg-[#4285F4] hover:bg-[#4285F4]/90 border-transparent text-white"

  defp get_social_button_classes(%{logo: "github", variant: "solid"}),
    do: "bg-[#24292F] hover:bg-[#24292F]/90 border-transparent text-white"

  defp get_social_button_classes(%{logo: "facebook", variant: "solid"}),
    do: "bg-[#1778F2] hover:bg-[#1778F2]/90 border-transparent text-white"

  defp get_social_button_classes(%{logo: "twitter", variant: "solid"}),
    do: "bg-[#1da1f2] hover:bg-[#1da1f2]/90 border-transparent text-white"

  defp get_social_button_classes(%{logo: "apple", variant: "solid"}),
    do: "bg-[#050708] hover:bg-[#050708]/90 border-transparent text-white"

  defp get_social_button_classes(%{logo: "linkedin", variant: "solid"}),
    do: "bg-[#0B65C2] hover:bg-[#0B65C2]/90 border-transparent text-white"
end

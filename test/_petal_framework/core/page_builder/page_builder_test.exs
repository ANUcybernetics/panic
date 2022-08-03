defmodule PetalFramework.PageBuilderTest do
  use ExUnit.Case, async: true
  alias PetalFramework.PageBuilder

  test "inject_into_line_below" do
    code = """
    scope "/", PetalProWeb do

      # page_builder:public_static_routes

      live_session :public, on_mount: {PetalProWeb.UserOnMountHooks, :maybe_assign_user} do
        # page_builder:public_live_routes
      end
    end
    """

    assert PageBuilder.inject_into_line_below(code, "public_static_routes", """
           get "/blah", PageController, :blah
           """) == """
           scope "/", PetalProWeb do

             # page_builder:public_static_routes
             get "/blah", PageController, :blah

             live_session :public, on_mount: {PetalProWeb.UserOnMountHooks, :maybe_assign_user} do
               # page_builder:public_live_routes
             end
           end
           """

    assert PageBuilder.inject_into_line_below(code, "public_live_routes", """
           live "/blah", BlahLive
           """) == """
           scope "/", PetalProWeb do

             # page_builder:public_static_routes

             live_session :public, on_mount: {PetalProWeb.UserOnMountHooks, :maybe_assign_user} do
               # page_builder:public_live_routes
               live "/blah", BlahLive
             end
           end
           """
  end
end

defmodule PetalFramework.SetLocalePlugPlugTest do
  use ExUnit.Case
  import Plug.Conn
  import Phoenix.ConnTest
  alias PetalFramework.SetLocalePlug

  defmodule MyGettext do
    use Gettext, otp_app: :panic
  end

  @default_options %SetLocalePlug.Config{
    gettext: MyGettext,
    extra_allowed_locales: ~w(nl)
  }

  describe "when a locale is given and there is no cookie" do
    test "it should set a cookie" do
      assert Gettext.get_locale(MyGettext) == "en"

      conn =
        build_conn(:get, "/", %{"locale" => "nl"})
        |> init_test_session(%{})
        |> fetch_session()
        |> fetch_cookies()
        |> SetLocalePlug.call(@default_options)

      assert conn.cookies["locale"] == "nl"
    end
  end

  describe "when no locale is given and there is no cookie" do
    test "it should do nothing" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> fetch_cookies()
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == nil
    end

    test "when headers contain accept-language, it should set that locale if supported" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> fetch_cookies()
             |> put_req_header("accept-language", "de, en-gb;q=0.8, nl;q=0.9, en;q=0.7")
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == "nl"
    end

    test "when headers contain accept-language with full language tags with country variants,
          it should set the locale if country variant is not supported" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> fetch_cookies()
             |> put_req_header(
               "accept-language",
               "de, en-gb;q=0.8, nl-nl;q=0.9, en;q=0.7, *;q=0.5"
             )
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == "nl"
    end

    test "when headers contain accept-language but none is accepted, it should do nothing" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> fetch_cookies()
             |> put_req_header("accept-language", "de, ak;q=0.9")
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == nil
    end

    test "when headers contain accept-language in incorrect format or language tags with larger range it does not fail" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> fetch_cookies()
             |> put_req_header(
               "accept-language",
               ",, hell#foo-bar-baz-1234%, zh-Hans-CN;q=0.5"
             )
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == nil
    end
  end

  describe "when no locale is given but there is a cookie" do
    test "it should set the cookie locale" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> put_resp_cookie("locale", "nl")
             |> fetch_cookies()
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == "nl"
    end

    test "when headers contain accept-language, it should redirect to cookie locale" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> put_resp_cookie("locale", "nl")
             |> fetch_cookies()
             |> put_req_header("accept-language", "de, en-gb;q=0.8, en;q=0.7")
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == "nl"
    end
  end

  describe "when an unsupported locale is given and there is no cookie" do
    test "it does nothing" do
      assert build_conn(:get, "/", %{"locale" => "de-at"})
             |> init_test_session(%{})
             |> fetch_session()
             |> fetch_cookies()
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == nil
    end
  end

  describe "when an unsupported locale is given but there is a cookie" do
    test "it sets the cookie locale" do
      assert build_conn(:get, "/", %{"locale" => "de-at"})
             |> init_test_session(%{})
             |> fetch_session()
             |> put_resp_cookie("locale", "nl")
             |> fetch_cookies()
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == "nl"
    end

    test "when the cookie is an unsupported locale, it should do nothing" do
      assert Gettext.get_locale(MyGettext) == "en"

      assert build_conn(:get, "/", %{})
             |> init_test_session(%{})
             |> fetch_session()
             |> put_resp_cookie("locale", "pl")
             |> fetch_cookies()
             |> SetLocalePlug.call(@default_options)
             |> get_session("locale") == nil
    end
  end
end

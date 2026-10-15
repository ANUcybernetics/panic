defmodule Panic.PlatformCredentialsTest do
  use Panic.DataCase, async: false

  alias Ash.Error.Forbidden
  alias Panic.Accounts
  alias Panic.Accounts.PlatformCredentials
  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  defp admin do
    Panic.Fixtures.user()
    |> Ash.Changeset.for_update(:set_admin, %{admin: true})
    |> Ash.update!(authorize?: false)
  end

  test "keys are encrypted at rest and decrypted for invocations" do
    Panic.Fixtures.set_credentials(openai_token: "sk-secret-openai")

    assert {:ok, "sk-secret-openai"} = PlatformCredentials.fetch_token(OpenAI)

    %{rows: [[stored]]} =
      Ecto.Adapters.SQL.query!(
        Panic.Repo,
        "SELECT encrypted_openai_token FROM platform_credentials"
      )

    refute stored =~ "sk-secret-openai"
  end

  test "a blank key leaves the stored key as it is" do
    Panic.Fixtures.set_credentials(replicate_token: "r8_original")
    Panic.Fixtures.set_credentials(replicate_token: "", gemini_token: "gemini-key")

    assert {:ok, "r8_original"} = PlatformCredentials.fetch_token(Replicate)
    assert {:ok, "gemini-key"} = PlatformCredentials.fetch_token(Gemini)
  end

  test "an unset key is an error naming the platform, except for Dummy" do
    assert {:error, "No API key set for OpenAI"} = PlatformCredentials.fetch_token(OpenAI)
    assert {:ok, _} = PlatformCredentials.fetch_token(Dummy)
  end

  test "missing/1 lists the platforms a network's models need that have no key" do
    Panic.Fixtures.set_credentials(gemini_token: "gemini-key")
    openai = Enum.find(Panic.Model.all(), &(&1.platform == OpenAI))
    gemini = Enum.find(Panic.Model.all(), &(&1.platform == Gemini))

    assert PlatformCredentials.missing([openai.id, gemini.id, "dummy-t2t", openai.id]) == [OpenAI]
  end

  test "Vestaboard keys are looked up by board" do
    Panic.Fixtures.set_credentials(vestaboard_panic_2_token: "board-two")

    assert PlatformCredentials.vestaboard_token(:panic_2) == "board-two"
    assert PlatformCredentials.vestaboard_token(:panic_1) == nil
  end

  test "only admins can read or change the credentials" do
    user = Panic.Fixtures.user()
    admin = admin()

    # reads are filtered, so a non-admin finds nothing
    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
             Accounts.get_platform_credentials(actor: user)

    assert {:ok, credentials} = Accounts.get_platform_credentials(actor: admin)

    assert {:error, %Forbidden{}} =
             Accounts.update_platform_credentials(credentials, %{openai_token: "stolen"}, actor: user)

    assert {:ok, _} =
             Accounts.update_platform_credentials(credentials, %{openai_token: "sk-new"}, actor: admin)

    assert {:ok, "sk-new"} = PlatformCredentials.fetch_token(OpenAI)
  end
end

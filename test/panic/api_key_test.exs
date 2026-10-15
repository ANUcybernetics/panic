defmodule Panic.ApiKeyTest do
  use Panic.DataCase, async: false

  alias Panic.Accounts

  setup do
    admin =
      Panic.Fixtures.user()
      |> Ash.Changeset.for_update(:set_admin, %{admin: true})
      |> Ash.update!(authorize?: false)

    {:ok, admin: admin}
  end

  test "admins can create keys, and only see the plaintext once", %{admin: admin} do
    key = Accounts.create_api_key!("laptop", actor: admin)

    assert "panic_" <> _ = key.__metadata__.plaintext_api_key
    assert key.user_id == admin.id
    assert key.expires_at == nil

    [listed] = Accounts.list_api_keys!(actor: admin)
    assert listed.id == key.id
    refute Map.has_key?(listed.__metadata__, :plaintext_api_key)
  end

  test "non-admins can't create keys" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Accounts.create_api_key("sneaky", actor: Panic.Fixtures.user())
  end

  test "users only see and revoke their own keys", %{admin: admin} do
    other_admin =
      Panic.Fixtures.user()
      |> Ash.Changeset.for_update(:set_admin, %{admin: true})
      |> Ash.update!(authorize?: false)

    key = Accounts.create_api_key!("mine", actor: admin)

    assert Accounts.list_api_keys!(actor: other_admin) == []
    assert {:error, _} = Accounts.destroy_api_key(key, actor: other_admin)
    assert :ok = Accounts.destroy_api_key(key, actor: admin)
  end

  test "keys are deleted with their user", %{admin: admin} do
    Accounts.create_api_key!("doomed", actor: admin)
    Accounts.destroy_user!(admin, authorize?: false)

    assert Ash.read!(Accounts.ApiKey, authorize?: false) == []
  end
end

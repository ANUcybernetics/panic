defmodule Panic.Accounts.PlatformCredentials do
  @moduledoc """
  The API keys PANIC! spends on model platforms and Vestaboards: a single
  row shared by every network, encrypted at rest with `Panic.Vault`. Its
  migration creates the row, so `Panic.Accounts.get_platform_credentials/1`
  always finds it.

  A blank key in `:update` leaves the stored key as it is, so the admin form
  never has to send a key back to the browser to keep it.
  """
  use Ash.Resource,
    otp_app: :panic,
    domain: Panic.Accounts,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshCloak]

  alias Panic.Platforms.Dummy
  alias Panic.Platforms.Gemini
  alias Panic.Platforms.OpenAI
  alias Panic.Platforms.Replicate

  @platform_keys [replicate_token: Replicate, openai_token: OpenAI, gemini_token: Gemini]
  @vestaboards [:panic_1, :panic_2, :panic_3, :panic_4]
  @keys Keyword.keys(@platform_keys) ++ Enum.map(@vestaboards, &:"vestaboard_#{&1}_token")

  sqlite do
    table "platform_credentials"
    repo Panic.Repo
  end

  cloak do
    vault(Panic.Vault)
    attributes(@keys)
    # keeps unset keys NULL, so the row shows which keys are set
    encrypt_nil?(false)
  end

  actions do
    defaults [:read]

    update :update do
      primary? true
      require_atomic? false
      accept @keys

      change fn changeset, _context ->
        Enum.reduce(@keys, changeset, fn key, changeset ->
          case Ash.Changeset.fetch_argument(changeset, key) do
            {:ok, blank} when blank in [nil, ""] -> Ash.Changeset.delete_argument(changeset, key)
            _ -> changeset
          end
        end)
      end
    end
  end

  policies do
    policy always() do
      authorize_if actor_attribute_equals(:admin, true)
    end
  end

  attributes do
    integer_primary_key :id

    for key <- @keys do
      attribute key, :string do
        public? true
        sensitive? true
      end
    end

    timestamps()
  end

  @doc "The credential fields, in display order."
  def keys, do: @keys

  @doc "The Vestaboards PANIC! has keys for."
  def vestaboards, do: @vestaboards

  @doc "The platform module whose key a field holds, or nil for a Vestaboard key."
  def platform(key), do: Keyword.get(@platform_keys, key)

  @doc """
  The key for a platform module, read as the system (runs spend the app's
  keys whoever started them).
  """
  def fetch_token(Dummy), do: {:ok, "dummy_token"}

  def fetch_token(platform) do
    with {key, _platform} <- Enum.find(@platform_keys, &(elem(&1, 1) == platform)),
         token when is_binary(token) <- Map.get(load!([key]), key) do
      {:ok, token}
    else
      _ -> {:error, "No API key set for #{platform_name(platform)}"}
    end
  end

  @doc "The key for a Vestaboard (e.g. `:panic_1`), or nil if it isn't set."
  def vestaboard_token(board) when board in @vestaboards do
    key = :"vestaboard_#{board}_token"
    Map.get(load!([key]), key)
  end

  @doc "The platforms the models (by id) need that have no key set. Dummy never needs one."
  def missing(model_ids) do
    credentials = Ash.read_one!(__MODULE__, authorize?: false)

    model_ids
    |> Enum.flat_map(&List.wrap(Panic.Model.by_id(&1)))
    |> Enum.map(& &1.platform)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == Dummy))
    |> Enum.filter(fn platform ->
      case Enum.find(@platform_keys, &(elem(&1, 1) == platform)) do
        {key, _} -> is_nil(Map.get(credentials, :"encrypted_#{key}"))
        nil -> true
      end
    end)
  end

  def platform_name(platform), do: platform |> Module.split() |> List.last()

  defp load!(keys), do: Ash.read_one!(__MODULE__, load: keys, authorize?: false)
end

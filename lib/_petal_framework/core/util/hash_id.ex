defmodule HashId do
  @default_opts [min_length: 10, salt_addition: ""]

  @doc """
  Encode an integer into an unguessable string. The second argument is the string length (defaults to 10)

  ## Examples

      iex> HashId.encode(1)
      "jv51er3x94"
      iex> HashId.encode(1, min_length: 20)
      "wRz0Vjv51er3x942brgJ"
      iex> HashId.encode(1, salt_addition: "xxx")
      "wRz0Vjv51er3x942brgJ"
  """
  def encode(id, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts) |> Enum.into(%{})
    Hashids.encode(coder(opts.min_length, opts.salt_addition), id)
  end

  def decode(data, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts) |> Enum.into(%{})
    List.first(Hashids.decode!(coder(opts.min_length, opts.salt_addition), data))
  end

  defp coder(min_length, salt_addition) do
    # We use the first 10 characters of the secret_key_base, which should be unique to each deployment.
    # For some reason, if we use the whole secret_key_base, adding salt_addition to the end of it has no effect.
    # We want salt_addition to allow devs to encode/decode with different salts.
    salt =
      String.slice(Application.get_env(:petal_pro, PetalProWeb.Endpoint)[:secret_key_base], 0..9) <>
        salt_addition

    Hashids.new(
      salt: salt,
      min_len: min_length
    )
  end
end

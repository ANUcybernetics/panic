defmodule Panic.Vault do
  @moduledoc """
  Encrypts the platform credentials at rest (see
  `Panic.Accounts.PlatformCredentials`). The AES-GCM key comes from the
  `PANIC_CLOAK_KEY` environment variable (base64, 32 bytes); see
  `config/runtime.exs`.
  """
  use Cloak.Vault, otp_app: :panic
end

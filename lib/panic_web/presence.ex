defmodule PanicWeb.Presence do
  @moduledoc """
  Phoenix Presence implementation for tracking viewers of invocations.
  
  This module tracks:
  - Who is viewing which network's invocations
  - What display mode they're using (grid, single, etc.)
  - Additional metadata like installation IDs
  
  Each network has its own presence topic: "invocation:<network_id>"
  """
  use Phoenix.Presence,
    otp_app: :panic,
    pubsub_server: Panic.PubSub
end
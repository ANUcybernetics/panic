defmodule PanicWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Panic.Engine, Panic.Watcher],
    open_api: "/open_api",
    open_api_title: "PANIC! API"
end

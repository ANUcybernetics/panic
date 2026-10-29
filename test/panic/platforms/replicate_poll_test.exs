defmodule Panic.Platforms.ReplicatePollTest do
  # sets global app env, so not async
  use ExUnit.Case, async: false

  alias Panic.Platforms.Replicate

  setup do
    Application.put_env(:panic, :replicate_req_options, plug: {Req.Test, Replicate})
    Application.put_env(:panic, :replicate_poll_options, interval_ms: 1)

    on_exit(fn ->
      Application.delete_env(:panic, :replicate_req_options)
      Application.delete_env(:panic, :replicate_poll_options)
    end)
  end

  defp stub_statuses(statuses) do
    test = self()
    {:ok, remaining} = Agent.start_link(fn -> statuses end)

    Req.Test.stub(Replicate, fn
      %{method: "POST", request_path: "/v1/predictions/abc/cancel"} = conn ->
        send(test, :cancelled)
        Req.Test.json(conn, %{"status" => "canceled"})

      conn ->
        status =
          Agent.get_and_update(remaining, fn [s | rest] ->
            {s, if(rest == [], do: [s], else: rest)}
          end)

        Req.Test.json(conn, %{"id" => "abc", "status" => status, "output" => "done"})
    end)
  end

  test "returns the prediction once it succeeds, waiting through starting and processing" do
    stub_statuses(~w(starting starting processing processing succeeded))

    assert {:ok, %{"output" => "done"}} = Replicate.get("abc", "token", 1_000)
    refute_received :cancelled
  end

  test "cancels a prediction still processing after the time limit" do
    stub_statuses(~w(processing))

    assert {:error, "Prediction timed out" <> _} = Replicate.get("abc", "token", 20)
    assert_received :cancelled
  end

  test "doesn't count time spent starting towards the limit" do
    stub_statuses(List.duplicate("starting", 30) ++ ["succeeded"])

    assert {:ok, _} = Replicate.get("abc", "token", 5)
  end
end

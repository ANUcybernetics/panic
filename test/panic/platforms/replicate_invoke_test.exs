defmodule Panic.Platforms.ReplicateInvokeTest do
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

  defp model(attrs \\ []) do
    struct!(
      %Panic.Model{
        id: "test",
        path: "owner/test",
        name: "Test",
        platform: Replicate,
        input_type: :text,
        output_type: :image
      },
      attrs
    )
  end

  # Stubs Replicate: the model lookup, the create request (answered with
  # `created`) and polls (answered with each of `polled` in turn, repeating
  # the last). Sends the test the create request's headers.
  defp stub(official?, created, polled \\ []) do
    test = self()
    {:ok, polls} = Agent.start_link(fn -> polled end)

    Req.Test.stub(Replicate, fn
      %{method: "GET", request_path: "/v1/models/owner/test"} = conn ->
        Req.Test.json(conn, %{"latest_version" => %{"id" => "v1"}, "is_official" => official?})

      %{method: "POST", request_path: "/v1/predictions"} = conn ->
        send(test, {:created, Map.new(conn.req_headers)})
        {status, body} = created
        conn |> Plug.Conn.put_status(status) |> Req.Test.json(Map.put(body, "id", "abc"))

      %{method: "GET", request_path: "/v1/predictions/abc"} = conn ->
        body =
          Agent.get_and_update(polls, fn [p | rest] ->
            {p, if(rest == [], do: [p], else: rest)}
          end)

        Req.Test.json(conn, Map.put(body, "id", "abc"))
    end)
  end

  test "returns a prediction that finishes within the sync wait without polling" do
    stub(true, {201, %{"status" => "succeeded", "output" => "url"}})

    assert {:ok, "url", _usage} = Replicate.invoke(model(), "a cat", "token")
    assert_received {:created, %{"prefer" => "wait=60", "cancel-after" => "1m"}}
  end

  test "polls a prediction that outlasts the sync wait" do
    stub(true, {202, %{"status" => "starting"}}, [
      %{"status" => "processing"},
      %{"status" => "succeeded", "output" => "url"}
    ])

    assert {:ok, "url", _usage} = Replicate.invoke(model(), "a cat", "token")
  end

  test "reports the prediction's metrics as its usage, with token counts named one way" do
    stub(
      true,
      {201,
       %{
         "status" => "succeeded",
         "output" => ["a ", "caption"],
         "metrics" => %{
           "predict_time" => 1.5,
           "token_input_count" => 10,
           "token_output_count" => 3
         }
       }}
    )

    assert {:ok, ["a ", "caption"], usage} = Replicate.invoke(model(), "a cat", "token")

    assert usage == %{
             "platform" => "replicate",
             "path" => "owner/test",
             "predict_time" => 1.5,
             "input_token_count" => 10,
             "output_token_count" => 3
           }
  end

  test "gives community models time to boot, and audio models time to run" do
    stub(false, {201, %{"status" => "succeeded"}})
    Replicate.invoke(model(), "a cat", "token")
    assert_received {:created, %{"cancel-after" => "5m"}}

    stub(true, {201, %{"status" => "succeeded"}})
    Replicate.invoke(model(output_type: :audio), "a cat", "token")
    assert_received {:created, %{"cancel-after" => "3m"}}
  end

  @tag :capture_log
  test "returns predictions Replicate cancelled at the deadline as errors" do
    stub(true, {202, %{"status" => "starting"}}, [%{"status" => "aborted"}])
    assert {:error, "Prediction aborted"} = Replicate.invoke(model(), "a cat", "token")
    # a model that couldn't start in time isn't retried
    assert_received {:created, _}
    refute_received {:created, _}

    stub(true, {202, %{"status" => "processing"}}, [%{"status" => "canceled"}])
    assert {:error, "Prediction canceled"} = Replicate.invoke(model(), "a cat", "token")
  end

  @tag :capture_log
  test "returns a failure without an error message as an error" do
    stub(true, {201, %{"status" => "failed", "error" => nil}})
    assert {:error, "Prediction failed"} = Replicate.invoke(model(), "a cat", "token")
  end

  test "returns a refusal as :nsfw without retrying it" do
    stub(true, {201, %{"status" => "failed", "error" => "Blocked by content policy (violence)"}})
    assert {:error, :nsfw} = Replicate.invoke(model(), "a cat", "token")
    assert_received {:created, _}
    refute_received {:created, _}
  end
end

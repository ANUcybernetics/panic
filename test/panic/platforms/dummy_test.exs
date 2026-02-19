defmodule Panic.Platforms.DummyTest do
  use ExUnit.Case, async: true

  alias Panic.Platforms.Dummy

  defp model do
    %Panic.Model{
      id: "dummy-error-t2t",
      platform: Dummy,
      path: "dummy/error-text-to-text",
      name: "Test",
      input_type: :text,
      output_type: :text,
      invoke: fn _, _, _ -> nil end
    }
  end

  describe "invoke_with_errors/4" do
    test "fail_n_times fails n times then succeeds" do
      assert {:error, _} = Dummy.invoke_with_errors(model(), "hello", "token", {:fail_n_times, 2})
      assert {:error, _} = Dummy.invoke_with_errors(model(), "hello", "token", {:fail_n_times, 2})
      assert {:ok, _} = Dummy.invoke_with_errors(model(), "hello", "token", {:fail_n_times, 2})
    end

    test "always_fail always returns error" do
      assert {:error, "simulated permanent error"} =
               Dummy.invoke_with_errors(model(), "hello", "token", :always_fail)

      assert {:error, "simulated permanent error"} =
               Dummy.invoke_with_errors(model(), "hello", "token", :always_fail)
    end
  end
end

defmodule Panic.ModelsTest do
  use Panic.DataCase
  alias Panic.Engine.Network
  alias Panic.Engine.Invocation

  describe "model helpers" do
    test "list all modules which conform to Model behaviour" do
      models = [
        Panic.Models.BLIP2,
        Panic.Models.StableDiffusion,
        Panic.Models.ClipCaptionReward,
        Panic.Models.GPT4o,
        Panic.Models.CogPromptParrot,
        Panic.Models.GPT4Turbo,
        Panic.Models.LLaVA,
        Panic.Models.ClipPrefixCaption,
        Panic.Models.Vicuna13B,
        Panic.Models.SDXL,
        Panic.Models.GPT4
      ]

      # check that they're all in the list
      assert Panic.Models.list() |> MapSet.new() == MapSet.new(models)
    end
  end

  describe "Panic.Engine.Invocation resource" do
    test "changeset for :create_first action with valid data creates an invocation" do
      network = network_fixture()
      valid_attrs = %{network: network, input: "my test input"}

      invocation =
        Invocation
        |> Ash.Changeset.for_create(:create_first, valid_attrs)
        |> Ash.create!()

      assert invocation.network_id == network.id
      assert invocation.input == valid_attrs.input
      assert invocation.sequence_number == 0
      assert invocation.run_number == nil
    end

    test "raise if there's no Invocation with a given id" do
      assert_raise Ash.Error.Invalid, fn -> Ash.get!(Invocation, 1234) end
    end

    test "read the created invocation back from the db" do
      %Invocation{id: invocation_id} = invocation_fixture()

      assert %Invocation{id: ^invocation_id} =
               Panic.Engine.get_invocation!(invocation_id)
    end
  end

  defp network_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "My Network",
          description: "A super cool network",
          models: [
            # TODO change this to an actual model module once they exist
            Panic.Engine
          ]
        },
        attrs
      )

    Network
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  defp invocation_fixture(attrs \\ %{}) do
    network = network_fixture()

    attrs =
      Map.merge(
        %{network: network, input: "my test input"},
        attrs
      )

    Invocation
    |> Ash.Changeset.for_create(:create_first, attrs)
    |> Ash.create!()
  end
end

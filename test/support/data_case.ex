defmodule Panic.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Panic.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Panic.DataCase

      alias Panic.Repo
    end
  end

  setup tags do
    Panic.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Panic.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    case changeset do
      %Ecto.Changeset{} ->
        Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
          Regex.replace(~r"%{(\w+)}", message, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)

      %Ash.Changeset{errors: errors} ->
        errors_to_map(errors)

      %{errors: errors} when is_list(errors) ->
        # Handle Ash.Error.Invalid and similar error structs
        errors_to_map(errors)

      _ ->
        %{}
    end
  end

  defp errors_to_map(errors) when is_list(errors) do
    errors
    |> Enum.reduce(%{}, fn error, acc ->
      case error do
        %Ash.Error.Changes.Required{field: field} when not is_nil(field) ->
          Map.update(acc, field, ["is required"], &["is required" | &1])

        %{path: path, field: field} = error when is_list(path) and not is_nil(field) ->
          # Handle nested errors for embedded resources
          interpolated_message = interpolate_error_message(error)

          # Create nested structure for embedded errors
          # e.g., path: [:watchers], field: :type -> %{watchers: [%{type: ["message"]}]}
          field_error = %{field => [interpolated_message]}
          nested_value = [field_error]

          # Build the nested structure
          path
          |> Enum.reverse()
          |> Enum.reduce(nested_value, fn key, value ->
            %{key => value}
          end)
          |> merge_nested_errors(acc)

        %{field: field} = error when not is_nil(field) ->
          # Only handle top-level field errors (no path)
          case error do
            %{path: _} ->
              # Skip - already handled above
              acc

            _ ->
              interpolated_message = interpolate_error_message(error)
              Map.update(acc, field, [interpolated_message], &[interpolated_message | &1])
          end

        %Ash.Error.Unknown.UnknownError{value: value, path: path} when is_list(value) and is_list(path) ->
          # Handle custom validation errors that return {:error, field: field, message: message}
          field = Keyword.get(value, :field)
          message = Keyword.get(value, :message)

          if field && message do
            # Create nested structure for embedded errors
            field_error = %{field => [message]}
            nested_value = [field_error]

            # Build the nested structure
            path
            |> Enum.reverse()
            |> Enum.reduce(nested_value, fn key, value ->
              %{key => value}
            end)
            |> merge_nested_errors(acc)
          else
            acc
          end

        %{path: path, fields: fields, message: message} when is_list(path) and is_list(fields) ->
          # Handle embedded validation errors with multiple fields
          # For embedded arrays, we need to nest the errors properly
          # e.g., path: [:watchers], fields: [:rows, :columns] -> %{watchers: [%{rows: ["message"], columns: ["message"]}]}
          embedded_errors =
            Enum.reduce(fields, %{}, fn field, field_acc ->
              Map.put(field_acc, field, [message])
            end)

          # For array embeds, we put errors in the first element
          nested_value = [embedded_errors]

          # Build the nested structure
          path
          |> Enum.reverse()
          |> Enum.reduce(nested_value, fn key, value ->
            %{key => value}
          end)
          |> merge_nested_errors(acc)

        %{path: path} = error when is_list(path) and path != [] ->
          # For errors with a path but no specific field
          message = extract_error_message(error)

          if message do
            Map.update(acc, path, [message], &[message | &1])
          else
            acc
          end

        _ ->
          acc
      end
    end)
    |> Map.new(fn {k, v} -> {k, Enum.reverse(v)} end)
  end

  defp errors_to_map(_), do: %{}

  defp extract_error_message(%{message: message} = error) when is_binary(message) do
    interpolate_error_message(error)
  end

  defp extract_error_message(%{message: message}) when is_function(message, 1), do: message.(%{})
  defp extract_error_message(_), do: nil

  defp interpolate_error_message(%{message: message, vars: vars}) when is_binary(message) and is_list(vars) do
    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      vars |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end

  defp interpolate_error_message(%{message: message}) when is_binary(message), do: message
  defp interpolate_error_message(_), do: nil

  defp merge_nested_errors(new_errors, existing_errors) when is_map(new_errors) and is_map(existing_errors) do
    Map.merge(existing_errors, new_errors, fn
      _key, [existing_map], [new_map] when is_map(existing_map) and is_map(new_map) ->
        # Merge embedded error maps
        [
          Map.merge(existing_map, new_map, fn _field, existing_msgs, new_msgs ->
            existing_msgs ++ new_msgs
          end)
        ]

      _key, existing, new when is_list(existing) and is_list(new) ->
        # Merge message lists
        existing ++ new

      _key, _existing, new ->
        # Default to new value
        new
    end)
  end

  defp merge_nested_errors(new_errors, existing_errors) when is_list(new_errors) and is_map(existing_errors) do
    # Handle case where new_errors is just an array like [%{field: ["error"]}]
    # This happens when there's no path to nest under
    case new_errors do
      [error_map] when is_map(error_map) ->
        # Merge the error map directly into existing errors
        Map.merge(existing_errors, error_map, fn _field, existing, new ->
          existing ++ new
        end)

      _ ->
        existing_errors
    end
  end
end

defmodule PetalFramework.PageBuilder do
  @moduledoc """
  Helper functions to create new pages. Similar to a generator but designed to be operated from a web UI.
  """
  require Logger

  @template_path "priv/templates/_petal_framework/page_builder/"

  def make_changes(changes), do: Enum.each(changes, &do_change/1)

  def do_change(
        [
          action: :inject_after_target_line,
          file_path: file_path,
          target_line: target_line,
          code: code
        ] = _opts
      ) do
    inject_after_target_line(file_path, target_line, code)
  end

  def do_change([action: :inject_before_final_end, file_path: file_path, code: code] = _opts) do
    inject_before_final_end(file_path, code)
  end

  def do_change(
        [
          action: :copy_template,
          template: template,
          destination_file_path: destination_file_path,
          assigns: assigns
        ] = _opts
      ) do
    template_file_path = @template_path <> template
    Logger.info("Copying template: #{template_file_path}")
    template = EEx.eval_file(template_file_path, assigns: assigns)
    Logger.info("Creating new file from template: #{destination_file_path}")
    create_file(destination_file_path, template)
  end

  def inject_into_line_below(code, target, code_to_inject) do
    regex = ~r/^([^\S\r\n]*)(#.*#{target})$/m
    Regex.replace(regex, code, "\\0\n\\1#{String.trim(code_to_inject)}", global: false)
  end

  # This will inject code below the line with the hook in it
  # Eg. if router line 10 is "  # page_builder:public_static"
  # Then inject_after_target_line("/path/to/file.ex", "public_static", "xxx") will add "xxx" to line 11
  defp inject_after_target_line(path_to_file, target_line, code_to_inject) do
    Logger.info("inject_after_target_line:#{path_to_file}")
    file_contents = File.read!(path_to_file)

    if String.contains?(file_contents, code_to_inject) do
      Logger.info("Already contains. Skipping...")
      :ok
    else
      new_file_contents = inject_into_line_below(file_contents, target_line, code_to_inject)

      case File.write(path_to_file, new_file_contents) do
        :ok ->
          Logger.info("File written: #{path_to_file}")
          :ok

        {:error, reason} ->
          Logger.error(reason)
          :error
      end
    end
  end

  defp inject_before_final_end(path_to_file, code_to_inject) do
    Logger.info("inject_before_final_end:#{path_to_file}")
    file_contents = File.read!(path_to_file)

    if String.contains?(file_contents, code_to_inject) do
      :ok
    else
      new_file_contents =
        file_contents
        |> String.trim_trailing()
        |> String.trim_trailing("end")
        |> Kernel.<>(code_to_inject)
        |> Kernel.<>("end\n")

      case File.write(path_to_file, new_file_contents) do
        :ok ->
          Logger.info("File written: #{path_to_file}")
          :ok

        {:error, reason} ->
          Logger.error(reason)
          :error
      end
    end
  end

  defp create_file(path, contents) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    true
  end
end

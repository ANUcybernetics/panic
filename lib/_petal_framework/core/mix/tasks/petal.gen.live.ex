defmodule Mix.Tasks.Petal.Gen.Live do
  @shortdoc "Generates LiveView, templates, and context for a resource using Petal Components"

  @moduledoc """
  This works the same as phx.gen.live but will use Tailwind styling and Petal Components where possible

  Test with all types of data:
  mix petal.gen.live Blog Post posts title slug:unique votes:integer cost:decimal tags:array:text popular:boolean drafted_at:datetime status:enum:unpublished:published:deleted published_at:utc_datetime published_at_usec:utc_datetime_usec deleted_at:naive_datetime deleted_at_usec:naive_datetime_usec alarm:time alarm_usec:time_usec secret:uuid:redact announcement_date:date weight:float user_id:references:users
  """
  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix petal.gen.live must be invoked from within your *_web application root directory"
      )
    end

    {context, schema} = Gen.Context.build(args)
    Gen.Context.prompt_for_code_injection(context)

    binding = [context: context, schema: schema, inputs: inputs(schema)]
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding, paths)
    |> print_shell_instructions()
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Kernel.++(context_files(context))
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp context_files(%Context{generate?: true} = context) do
    Gen.Context.files_to_be_generated(context)
  end

  defp context_files(%Context{generate?: false}) do
    []
  end

  defp files_to_be_generated(%Context{schema: schema, context_app: context_app}) do
    web_prefix = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    web_path = to_string(schema.web_path)
    live_subdir = "#{schema.singular}_live"

    [
      {:eex, "show.ex", Path.join([web_prefix, "live", web_path, live_subdir, "show.ex"])},
      {:eex, "index.ex", Path.join([web_prefix, "live", web_path, live_subdir, "index.ex"])},
      {:eex, "form_component.ex",
       Path.join([web_prefix, "live", web_path, live_subdir, "form_component.ex"])},
      {:eex, "form_component.html.heex",
       Path.join([web_prefix, "live", web_path, live_subdir, "form_component.html.heex"])},
      {:eex, "index.html.heex",
       Path.join([web_prefix, "live", web_path, live_subdir, "index.html.heex"])},
      {:eex, "show.html.heex",
       Path.join([web_prefix, "live", web_path, live_subdir, "show.html.heex"])},
      {:eex, "live_test.exs",
       Path.join([test_prefix, "live", web_path, "#{schema.singular}_live_test.exs"])}
    ]
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context)
    Mix.Phoenix.copy_from(paths, "priv/templates/_petal_framework/petal.gen.live", binding, files)
    if context.generate?, do: Gen.Context.copy_new_files(context, paths, binding)

    context
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema, context_app: ctx_app} = context) do
    prefix = Module.concat(context.web_module, schema.web_namespace)
    web_path = Mix.Phoenix.web_path(ctx_app)

    if schema.web_namespace do
      Mix.shell().info("""

      Add the live routes to your #{schema.web_namespace} :browser scope in #{web_path}/router.ex:

          scope "/#{schema.web_path}", #{inspect(prefix)}, as: :#{schema.web_path} do
            pipe_through :browser
            ...

      #{for line <- live_route_instructions(schema), do: "      #{line}"}
          end
      """)
    else
      Mix.shell().info("""

      Add the live routes to your browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

      #{for line <- live_route_instructions(schema), do: "    #{line}"}
      """)
    end

    if context.generate?, do: Gen.Context.print_shell_instructions(context)
  end

  defp live_route_instructions(schema) do
    [
      ~s|live "/#{schema.plural}", #{inspect(schema.alias)}Live.Index, :index\n|,
      ~s|live "/#{schema.plural}/new", #{inspect(schema.alias)}Live.Index, :new\n|,
      ~s|live "/#{schema.plural}/:id/edit", #{inspect(schema.alias)}Live.Index, :edit\n\n|,
      ~s|live "/#{schema.plural}/:id", #{inspect(schema.alias)}Live.Show, :show\n|,
      ~s|live "/#{schema.plural}/:id/show/edit", #{inspect(schema.alias)}Live.Show, :edit|
    ]
  end

  @doc false
  def inputs(%Schema{} = schema) do
    Enum.map(schema.attrs, fn
      {_, {:references, _}} ->
        ""

      {key, :integer} ->
        ~s(<.form_field type="number_input" form={f} field={#{inspect(key)}} />)

      {key, :float} ->
        ~s(<.form_field type="number_input" form={f} field={#{inspect(key)}} />)

      {key, :decimal} ->
        ~s(<.form_field type="number_input" form={f} field={#{inspect(key)}} />)

      {key, :boolean} ->
        ~s(<.form_field type="checkbox" form={f} field={#{inspect(key)}} />)

      {key, :text} ->
        ~s(<.form_field type="textarea" form={f} field={#{inspect(key)}} />)

      {key, :date} ->
        ~s(<.form_field type="date_select" form={f} field={#{inspect(key)}} />)

      {key, :time} ->
        ~s(<.form_field type="time_select" form={f} field={#{inspect(key)}} />)

      {key, :time_usec} ->
        ~s(<.form_field type="time_select" form={f} field={#{inspect(key)}} />)

      {key, :utc_datetime} ->
        ~s(<.form_field type="datetime_select" form={f} field={#{inspect(key)}} />)

      {key, :utc_datetime_usec} ->
        ~s(<.form_field type="datetime_select" form={f} field={#{inspect(key)}} />)

      {key, :naive_datetime} ->
        ~s(<.form_field type="datetime_select" form={f} field={#{inspect(key)}} />)

      {key, :naive_datetime_usec} ->
        ~s(<.form_field type="datetime_select" form={f} field={#{inspect(key)}} />)

      {key, {:array, :integer}} ->
        ~s(<.form_field type="checkbox_group" form={f} field={#{inspect(key)}} options={["1": 1, "2": 2]} />)

      {key, {:array, _}} ->
        ~s(<.form_field type="checkbox_group" form={f} field={#{inspect(key)}} options={["Option 1": "option1", "Option 2": "option2"]} />)

      {key, {:enum, _}} ->
        ~s|<.form_field type="select" form={f} field={#{inspect(key)}} options={Ecto.Enum.values(#{inspect(schema.module)}, #{inspect(key)})} prompt="Choose a value" />|

      {key, _} ->
        ~s(<.form_field type="text_input" form={f} field={#{inspect(key)}} />)
    end)
  end
end

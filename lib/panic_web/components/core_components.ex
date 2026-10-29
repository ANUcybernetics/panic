defmodule PanicWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  These follow the Phoenix 1.8 generator's components, styled with
  [daisyUI](https://daisyui.com/components/) classes over Tailwind CSS. The
  daisyUI theme (the PANIC! colours) is defined in `assets/css/app.css`, so
  style with semantic colours (`bg-base-200`, `text-primary`, `btn-error`)
  rather than raw palette ones.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use Gettext, backend: PanicWeb.Gettext

  alias Phoenix.HTML.FormField
  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  It's a native `<dialog>` opened with `showModal()` by the `Modal` hook
  while `:show` is true. `:on_cancel` runs when the user closes it (Esc, a
  backdrop click or the close button), for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <dialog
      id={@id}
      phx-hook="Modal"
      data-show={to_string(@show)}
      data-cancel={@on_cancel}
      class="modal"
    >
      <div id={"#{@id}-content"} class="modal-box max-w-2xl p-6 sm:p-10">
        <form method="dialog" class="absolute top-3 right-3">
          <button class="btn btn-sm btn-circle btn-ghost" aria-label={gettext("close")}>
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </form>
        {render_slot(@inner_block)}
      </div>
      <form method="dialog" class="modal-backdrop">
        <button tabindex="-1">{gettext("close")}</button>
      </form>
    </dialog>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a button, or a link styled as one when given `href`, `navigate`
  or `patch`.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
      <.button phx-click="delete" variant="error" size="sm">Delete</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled form type)

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary secondary ghost error), default: "secondary"
  attr :size, :string, values: ~w(sm md), default: "md"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [
        "btn",
        button_variant(assigns.variant),
        assigns.size == "sm" && "btn-sm",
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  defp button_variant("primary"), do: "btn-primary"
  defp button_variant("secondary"), do: "btn-secondary"
  defp button_variant("ghost"), do: "btn-ghost"
  defp button_variant("error"), do: "btn-error btn-soft"

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"

  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :help, doc: "a hint shown under the input"

  def input(%{field: %FormField{} = field} = assigns) do
    errors = if used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    # a nested form gets an embedded resource's errors both from itself and
    # from the parent's cast of the same argument
    |> assign(:errors, errors |> Enum.map(&translate_error(&1)) |> Enum.uniq())
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset">
      <label class="label gap-3 text-base-content">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "checkbox checkbox-sm checkbox-primary"}
          aria-invalid={@errors != [] && "true"}
          aria-describedby={error_id(@id, @errors)}
          {@rest}
        />
        {@label}
      </label>
      <p :if={@help != []} class="label text-wrap">{render_slot(@help)}</p>
      <.field_errors id={error_id(@id, @errors)} errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset">
      <label :if={@label} for={@id} class="fieldset-legend">{@label}</label>
      <select
        id={@id}
        name={@name}
        class={[@class || "select w-full", @errors != [] && "select-error"]}
        multiple={@multiple}
        aria-invalid={@errors != [] && "true"}
        aria-describedby={error_id(@id, @errors)}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :if={@help != []} class="label text-wrap">{render_slot(@help)}</p>
      <.field_errors id={error_id(@id, @errors)} errors={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset">
      <label :if={@label} for={@id} class="fieldset-legend">{@label}</label>
      <textarea
        id={@id}
        name={@name}
        class={[@class || "textarea w-full min-h-24", @errors != [] && "textarea-error"]}
        aria-invalid={@errors != [] && "true"}
        aria-describedby={error_id(@id, @errors)}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@help != []} class="label text-wrap">{render_slot(@help)}</p>
      <.field_errors id={error_id(@id, @errors)} errors={@errors} />
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset">
      <label :if={@label} for={@id} class="fieldset-legend">{@label}</label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[@class || "input w-full", @errors != [] && "input-error"]}
        aria-invalid={@errors != [] && "true"}
        aria-describedby={error_id(@id, @errors)}
        {@rest}
      />
      <p :if={@help != []} class="label text-wrap">{render_slot(@help)}</p>
      <.field_errors id={error_id(@id, @errors)} errors={@errors} />
    </div>
    """
  end

  defp error_id(nil, _errors), do: nil
  defp error_id(_id, []), do: nil
  defp error_id(id, _errors), do: "#{id}-error"

  attr :id, :string, default: nil
  attr :errors, :list, required: true

  defp field_errors(assigns) do
    ~H"""
    <div :if={@errors != []} id={@id}>
      <p :for={msg <- @errors} class="mt-1 flex gap-2 items-center text-sm text-error">
        <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
        {msg}
      </p>
    </div>
    """
  end

  @doc """
  Renders a page header with title, and actions that wrap below it on
  narrow screens.
  """
  attr :class, :any, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["flex flex-wrap items-center justify-between gap-4 pb-6", @class]}>
      <div class="min-w-0">
        <h1 class="text-xl font-semibold leading-8 text-primary-content break-words">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex flex-wrap gap-2">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a section heading, with optional actions on the right.
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :actions

  def section_header(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center justify-between gap-2 mb-4", @class]}>
      <h2 class="text-lg font-semibold text-primary-content">{render_slot(@inner_block)}</h2>
      <div :if={@actions != []} class="flex flex-wrap gap-2">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling. It scrolls sideways when it's wider
  than the screen, and its actions sit together in the last column.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
    attr :class, :any
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto rounded-box border border-base-300">
      <table class="table">
        <thead>
          <tr>
            <th :for={col <- @col} class={col[:class]}>{col[:label]}</th>
            <th :if={@action != []}>
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={@row_click && "hover:bg-base-200"}
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={[@row_click && "hover:cursor-pointer", col[:class]]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0">
              <div class="flex justify-end gap-2 whitespace-nowrap">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # the error messages in our forms and APIs are generated dynamically, so
    # we call Gettext with our backend as first argument (the "errors" domain)
    if count = opts[:count] do
      Gettext.dngettext(PanicWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(PanicWeb.Gettext, "errors", msg, opts)
    end
  end
end

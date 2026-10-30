defmodule PanicWeb.NetworkLive.TerminalComponent do
  @moduledoc false
  use PanicWeb, :live_component

  alias Panic.Engine.Errors.RunLocked

  @impl true
  def render(assigns) do
    ~H"""
    <div class={assigns[:class]}>
      <.form
        for={@form}
        id={"#{@id}-form"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="start-run"
      >
        <.input
          field={@form[:input]}
          type="textarea"
          label="Prompt"
          placeholder="Ready for new input"
          rows="1"
          class="textarea textarea-lg w-full min-h-0 max-h-[8lh] resize-none [field-sizing:content]"
          phx-hook=".TerminalLockoutTimer"
          data-ready-at={lockout_ready_at(@genesis_invocation, @network)}
        />
      </.form>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".TerminalLockoutTimer">
        export default {
          mounted() {
            // the prompt is a textarea so it can grow, but a prompt is one line:
            // Enter submits it (unless it's confirming an IME composition)
            this.el.addEventListener("keydown", (event) => {
              if (event.key === "Enter" && !event.isComposing) {
                event.preventDefault();
                this.el.form.requestSubmit();
              }
            });
            this.startTimer();
          },

          updated() {
            this.startTimer();
          },

          destroyed() {
            if (this.timer) {
              clearInterval(this.timer);
              this.timer = null;
            }
          },

          startTimer() {
            if (this.timer) {
              clearInterval(this.timer);
            }
            this.updateDisplay();
            this.timer = setInterval(() => this.updateDisplay(), 1000);
          },

          updateDisplay() {
            const readyAt = this.el.dataset.readyAt;
            if (!readyAt) {
              this.el.placeholder = "Ready for new input";
              this.el.disabled = false;
              return;
            }
            const timeLeft = Math.max(0, Math.ceil((new Date(readyAt) - new Date()) / 1000));
            if (timeLeft > 0) {
              this.el.placeholder = `${timeLeft} second${timeLeft !== 1 ? "s" : ""} until ready for new input`;
              this.el.disabled = true;
              this.el.value = "";
            } else {
              this.el.placeholder = "Ready for new input";
              if (this.el.disabled) {
                this.el.disabled = false;
                this.el.focus();
              }
            }
          },
        };
      </script>
      <p :if={@run_error} id={"#{@id}-run-error"} role="alert" class="mt-2 text-error">
        {@run_error}
      </p>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:run_error, fn -> nil end)
     |> assign_form()}
  end

  @impl true
  def handle_event("validate", %{"invocation" => invocation_params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, invocation_params))}
  end

  def handle_event("validate", _params, socket) do
    # Handle the case where only _target is sent (e.g., on field blur)
    # In this case, we don't need to validate as there are no new params
    {:noreply, socket}
  end

  def handle_event("start-run", %{"invocation" => invocation_params}, socket) do
    if closed?(socket.assigns[:expires_at]) do
      {:noreply, assign(socket, :run_error, "This terminal has closed")}
    else
      start_run(socket, invocation_params["input"] || "")
    end
  end

  defp start_run(socket, prompt) do
    network = socket.assigns.network

    # runs always act as the network owner, whoever typed the prompt
    case Panic.Engine.start_run(network, prompt, actor: network.user) do
      {:ok, genesis_invocation} ->
        notify_parent({:genesis_invocation, genesis_invocation})
        socket = assign(socket, genesis_invocation: genesis_invocation, run_error: nil)
        {:noreply, assign_form(socket)}

      # shown inline: a flash set in a live component is dropped unless it navigates
      {:error, error} ->
        {:noreply, assign(socket, :run_error, run_error_message(error))}
    end
  end

  # an anonymous terminal closes when its QR code token expires
  defp closed?(nil), do: false
  defp closed?(expires_at), do: DateTime.after?(DateTime.utc_now(), expires_at)

  defp run_error_message(%Ash.Error.Invalid{errors: [%RunLocked{} | _]}), do: "Please wait before starting a new run"

  defp run_error_message(%{errors: [_ | _] = errors}) do
    Enum.map_join(errors, "; ", fn error ->
      Map.get(error, :message) || Exception.message(error)
    end)
  end

  defp run_error_message(error), do: Exception.message(error)

  defp assign_form(%{assigns: %{network: network}} = socket) do
    form =
      Panic.Engine.form_to_start_run(
        as: "invocation",
        prepare_source: &Ash.Changeset.set_argument(&1, :network, network),
        actor: socket.assigns.current_user
      )

    assign(socket, form: to_form(form))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp lockout_ready_at(genesis_invocation, network) when not is_nil(genesis_invocation) do
    lockout_end = DateTime.shift(genesis_invocation.inserted_at, second: network.lockout_seconds)

    if DateTime.before?(DateTime.utc_now(), lockout_end) do
      DateTime.to_iso8601(lockout_end)
    end
  end

  defp lockout_ready_at(_, _), do: nil
end

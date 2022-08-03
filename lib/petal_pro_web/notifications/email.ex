defmodule PetalPro.Email do
  @moduledoc """
  Houses functions that generate Swoosh email structs.
  An Swoosh email struct can be delivered by a Swoosh mailer (see mailer.ex & user_notifier.ex). Eg:

      PetalPro.Email.confirm_register_email(user.email, url)
      |> PetalPro.Mailer.deliver()
  """

  use Phoenix.Swoosh,
    view: PetalProWeb.EmailView,
    layout: {PetalProWeb.EmailView, "email_layout.html"}

  def template(email) do
    base_email()
    |> to(email)
    |> subject("Template for showing how to do headings, buttons etc in emails")
    |> render_body("template.html")
    |> premail()
  end

  def confirm_register_email(email, url) do
    base_email()
    |> to(email)
    |> subject("Confirm instructions")
    |> render_body("confirm_register_email.html", %{url: url})
    |> premail()
  end

  def reset_password(email, url) do
    base_email()
    |> to(email)
    |> subject("Reset password")
    |> render_body("reset_password.html", %{url: url})
    |> premail()
  end

  def change_email(email, url) do
    base_email()
    |> to(email)
    |> subject("Change email")
    |> render_body("change_email.html", %{url: url})
    |> premail()
  end

  def org_invitation(org, invitation, url) do
    base_email()
    |> to(invitation.email)
    |> subject("Invitation to join #{org.name}")
    |> render_body("org_invitation.html", %{org: org, invitation: invitation, url: url})
    |> premail()
  end

  def passwordless_pin(email, pin) do
    base_email()
    |> to(email)
    |> subject("#{pin} is your pin code")
    |> render_body("passwordless_pin.html", %{pin: pin})
    |> premail()
  end

  # For when you don't need any HTML and just want to send text
  def text_only_email(to_email, subject, body, cc \\ []) do
    new()
    |> to(to_email)
    |> from({from_name(), from_email()})
    |> subject(subject)
    |> text_body(body)
    |> cc(cc)
  end

  defp base_email(opts \\ []) do
    {unsubscribe_url, _opts} = Keyword.pop(opts, :unsubscribe_url)

    new()
    |> from({from_name(), from_email()})
    |> assign(:unsubscribe_url, unsubscribe_url)
  end

  # Inlines your CSS and adds a text option (email clients prefer this)
  defp premail(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end

  defp from_name do
    PetalPro.config(:mailer_default_from_name)
  end

  defp from_email do
    PetalPro.config(:mailer_default_from_email)
  end

  # Use this when you want to have different types of emails a user can sub/unsub to.
  # User field must begin with "is_subscribed_to_"
  # Eg:  user.is_subscribed_to_comment_replies
  # base_email(unsubscribe_url: unsub_url(comment_owner, "comment_replies"))
  def get_unsubscribe_url(user, email_kind) do
    PetalPro.Accounts.NotificationSubscriptions.unsubscribe_url(user, email_kind)
  end
end

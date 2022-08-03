defmodule PetalProWeb.PageView do
  use PetalProWeb, :view
  alias PetalProWeb.Components.LandingPage

  # SETUP_TODO: Add your license content here.
  def license_markdown(),
    do: """
    # License

    To the maximum extent permitted by law, you must indemnify us ('#{PetalPro.config(:business_name)}'), and hold us harmless, against any Liability suffered by us arising from or in connection with your use of our Platform or any breach of this contract or any applicable laws by you. This indemnity is a continuing obligation, independent from the other obligations under this contract, and continues after this contract ends. It is not necessary for us to suffer or incur any Liability before enforcing a right of indemnity under this contract.
    """

  # SETUP_TODO: Ensure this privacy policy suits your needs. Rendered in privacy.html.heex
  # This privacy policy template was taken from https://github.com/ArthurGareginyan/privacy-policy-template.
  def privacy_markdown(),
    do: """
    # Privacy Policy

    #{PetalPro.config(:business_name)} takes your privacy seriously. To better protect your privacy we provide this privacy policy notice explaining the way your personal information is collected and used.


    ## Collection of Routine Information

    This website track basic information about their users. This information includes, but is not limited to, IP addresses, browser details, timestamps and referring pages. None of this information can personally identify specific users to this website. The information is tracked for routine administration and maintenance purposes.


    ## Cookies

    Where necessary, this website uses cookies to store information about a visitor's preferences and history in order to better serve the user and/or present the user with customized content.


    ## Advertisement and Other Third Parties

    Advertising partners and other third parties may use cookies, scripts and/or web beacons to track users activities on this website in order to display advertisements and other useful information. Such tracking is done directly by the third parties through their own servers and is subject to their own privacy policies. This website has no access or control over these cookies, scripts and/or web beacons that may be used by third parties. Learn how to [opt out of Google's cookie usage](http://www.google.com/privacy_ads.html).


    ## Links to Third Party Websites

    We have included links on this website for your use and reference. We are not responsible for the privacy policies on these websites. You should be aware that the privacy policies of these websites may differ from our own.


    ## Security

    The security of your personal information is important to us, but remember that no method of transmission over the Internet, or method of electronic storage, is 100% secure. While we strive to use commercially acceptable means to protect your personal information, we cannot guarantee its absolute security.


    ## Changes To This Privacy Policy

    This Privacy Policy is effective as of #{Timex.shift(Timex.now(), days: -1) |> format_date()} and will remain in effect except with respect to any changes in its provisions in the future, which will be in effect immediately after being posted on this page.

    We reserve the right to update or change our Privacy Policy at any time and you should check this Privacy Policy periodically. If we make any material changes to this Privacy Policy, we will notify you either through the email address you have provided us, or by placing a prominent notice on our website.


    ## Contact Information

    For any questions or concerns regarding the privacy policy, please send us an email to #{PetalPro.config(:support_email)}.
    """
end

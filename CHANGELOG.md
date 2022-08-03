# Changelog
### 1.3.0 - 2022-06-17 02:43:55
### Added
- Two-factor authentication using time-based one time passwords (paired with something like Google Authenticator)

### Changed
- Decoupled DashboardLive from Orgs so you can get started quicker if you don't want orgs
- Can pass a custom header class to the public layout
- Sidebar and stacked layouts now support grouped menu items (see dev_layout_component.ex for an example)
- Update Tailwind to 3.1
- Split CSS into different files thanks to Tailwind 3.1

### Fixed
- Onboarding now remembers user_return_to
- Fixed nav dropdown bug after modal toggle
- Fixed gettext in live views
### 1.2.0 - 2022-05-31 07:34:11
### Added
- Login with Google & Github - easy to add more auth providers
- Passwordless auth - register/sign in via a code sent to your email
- Orgs - create an org, invite & manage members, and more
- User lifecycle actions - run code after actions like register, sign_in, sign_out, password_reset, etc
- New generator: mix petal.gen.html (same args as phx.gen.html)
- New component: <.markdown content=""> & <.pretty_markdown content=""> (uses Tailwind Typography plugin)
- Added License and Privacy pages (with some content from a template to get you started)
- New layout: <.layout type="public">, for public marketing related pages like landing, about us, privacy, etc
- Hooks can now be run in dead views if compatible (see color-scheme-hook.js as an example)

### Changed
- Simpler config access (`Panic.config(:app_name)` instead of `Application.get_env(:panic, :app_name)`)
- Refactor <.layout> to take less props
- Refactor dark/light mode system. Much simpler now and no longer needs cookies
- Put Petal Pro Components in their own folder for easier future upgrades (can duplicate if you want to modify them)
- Sidebar and stacked layout have a new slot for the top right corner (if you want to add something like a notifications bell)

### Fixed
- Log metadata wasn't being cast
- More user actions are logged
- Fixed petal.live generator tests
- Added tests for user settings live views
### 1.1.1 - 2022-03-12 20:45:36
- Bump Oban version to stop random error showing
- Bump Petal Components
- Use new <.table> component in petal.gen.live generator & logs
- Dark mode persists on all pages with cookies
- Fix logo showing twice in emails
- Improved the Fly.io deploy flow
- Fix admin user search
- Remove guide (this is now online)
### 1.1.0 - 2022-02-28 00:08:52
- Added generator `mix petal.gen.live`
- Add gettext throughout public facing templates
- Improved dev_guide
- Add Oban
- Easy Fly.io deployment

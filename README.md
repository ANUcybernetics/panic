<p align="center">
  <img src="https://res.cloudinary.com/wickedsites/image/upload/v1650064156/petal/panic_jbuqvj.png" height="128">

  <p align="center">
    Launch beautiful Phoenix web apps with this boilerplate project.
  </p>
</p>

<p align="center">
  <a href="https://docs.petal.build">DOCS</a>
</p>

## Launching new projects

We recommend downloading the latest version from the "Releases" section. The `main` branch will be the most recent but there is a slightly higher chance of bugs (although we will endeavour to keep the `main` branch as stable as possible).

## Get up and running

For more comprehensive install instructions, please see the [installation guide](https://docs.petal.build/petal-pro-documentation/fundamentals/installation).

0. Download the [latest release](https://petal.build/downloads) or for the bleeding edge, clone this project
0. Install Elixir & Erlang if you haven't already - see below for more info
0. Optionally rename your project (open the file `rename_phoenix_project.sh` and read the instructions at the top)
0. Optionally change your database name in `dev.exs`
1. Setup the project with `mix setup`
2. Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
3. Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
4. Do a global search for `SETUP_TODO` and follow the instructions to mold the boilerplate to your brand

## Managing Elixir & Erlang & Node with asdf

We use [asdf](https://asdf-vm.com) for managing tool versions.

The file `.tool-version` tells asdf which versions we use.

Run `asdf install` to install those versions.

## Contributing

Petal Pro is a paid product but we welcome PR's if you find small bugs / typos / improvements. Let us know if you want to contribute in a more significant way and we can offer unlimited membership in return.

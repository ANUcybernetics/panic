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

**Assumptions:**
- You have Elixir & Erlang installed
- You have Postgres installed and running (optional - see "Using Docker for Postgres" below

If you don't meet this assumptions you can read our [comprehensive install instructions](https://docs.petal.build/petal-pro-documentation/fundamentals/installation).

**The steps**
1. `mix setup` (this get dependencies, setup database, migrations, seeds, install esbuild + Tailwind)
1. `iex -S mix phx.server` (starts the server in IEX mode)
1. Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

**Moving forward:**
- Do a global search for `SETUP_TODO` and follow the instructions to mold the boilerplate to your brand
- Optional: Follow our tutorial ["Creating a web app from start to finish"](https://docs.petal.build/petal-pro-documentation/guides/creating-a-web-app-from-start-to-finish) to get an overview of Petal Pro
## Using Docker for Postgres

If your system doesn't have Postgres you can use docker-compose to run it in a container (saves you having to install it).

| Command | Description |
| --- | ----------- |
| `docker compose up` | Start in the foreground |
| `docker compose up -d` | Start in the background |
| `docker compose down` | Stop the containers |
| `docker compose down -v` | Stop and delete all Postgres data by removing the volume |
| `docker compose exec db psql --username postgres` | Access through psql|

The connection details for any local clients would be the following:

```
Host: localhost
Port: 5432
User: postgres
Password: postgres
```

## Renaming

Rename your project by opening the file `rename_phoenix_project.sh` and reading the instructions at the top.

Note that it is not recommended to rename the project if you wish to keep pulling in Petal Pro updates. This is because it can be much harder to update after you have renamed.

## Maintaining code quality as you develop

Run `mix quality` to look for issues with your code. This will run each of these tasks:

* `mix format --check-formatted` (formats your code)
* `mix sobelow --config` (security analysis)
* `mix coveralls` (test coverage)
* `mix credo` (code quality)

If the output is overwhelming, try running one at a time.

## Contributing

Petal Pro is a paid product but we welcome PR's if you find small bugs / typos / improvements. Let us know if you want to contribute in a more significant way and we can offer unlimited membership in return.

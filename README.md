# weheat-ex

Elixir client for the [WeHeat](https://www.weheat.nl) third-party API.

Thin by design: one function per endpoint, DTOs mirror the Python
[`weheat`](https://pypi.org/project/weheat/) SDK 1:1 so its docs and the Home Assistant
integration map directly. No caching, no behaviour layer. Uses `Req` and Elixir's native `JSON`.

## Install

```elixir
def deps do
  [{:weheat, "~> 0.1"}]
end
```

## Auth setup

WeHeat uses Keycloak (`auth.weheat.nl`, realm `Weheat`). No registration needed: log in with
your normal WeHeat account against the public `WeheatCommunityAPI` client
(`Weheat.Auth.community_client_id/0`, no secret). The confidential `HomeAssistantAPI` client,
whose ID and secret WeHeat publishes in its
[knowledge base](https://support.weheat.nl/s/article/Is-er-een-offici%C3%ABle-Home-Assistant-integratie),
works too; pass its secret.

```elixir
client_id = Weheat.Auth.community_client_id()

# First login with your account; store token.refresh_token somewhere safe.
{:ok, token} = Weheat.Auth.password_grant(client_id, nil, email, password)

# Later runs: a process that refreshes before expiry. Keycloak rotates refresh tokens,
# so persist the new one in on_refresh or a restart locks you out.
{:ok, src} =
  Weheat.Auth.TokenSource.start_link(
    client_id: client_id,
    refresh_token: token.refresh_token,
    on_refresh: fn token -> MyApp.save(token.refresh_token) end
  )

client = Weheat.new(token: src)

# Or a static access token:
client = Weheat.new(token: "eyJ...")
```

## Quickstart

```elixir
{:ok, me} = Weheat.me(client)
{:ok, %{data: [pump | _]}} = Weheat.heat_pumps(client)
{:ok, latest} = Weheat.latest_log(client, pump.id)
{:ok, logs} = Weheat.logs(client, pump.id, ~U[2026-09-01 00:00:00Z], ~U[2026-09-02 00:00:00Z], :Hour)
```

Functions: `me/1`, `heat_pumps/2`, `heat_pump/2`, `latest_log/2`, `logs/5`, `raw_logs/4`,
`energy_logs/5`, `energy_total/2`. All return `{:ok, dto}` or `{:error, %Weheat.Error{}}`.

## Rate limit

WeHeat allows 34 requests per hour per user, shared across every client using that account.
The application starts `Weheat.RateLimiter` at 30/hour and every call blocks on it. Configure
or disable:

```elixir
config :weheat, rate_limit: 10, rate_window_ms: :timer.hours(1)

Weheat.new(token: src, rate_limiter: false)
```

Per-request windows per interval: Minute 2 days, FiveMinute 1 week, FifteenMinute and Hour
1 month, Day 1 year, Week 2 years, Month 5 years. `raw_logs/4` covers at most 4 hours.

## Development

```bash
mise install
mix deps.get
mix test
WEHEAT_LIVE=1 mix test --only live   # hits the real API, uses 2 requests
```

Fixtures in `test/fixtures/` are synthetic until real responses are recorded.

## Credits

DTO shapes follow the Python `weheat` SDK by WeHeat. MIT.

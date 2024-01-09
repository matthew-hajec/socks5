import Config

config :proxy_utils, :forwarder, ProxyUtils.Forwarders.TokenBucket

config :proxy_utils, :connector, ProxyUtils.Connectors.PassThrough
config :proxy_utils, :connector_conf, perform_dns: true

config :proxy_utils, :recv_timeout, 5000

config :proxy_utils, :ip, {127, 0, 0, 1}

config :proxy_utils, :port, 2030

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

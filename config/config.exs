import Config

config :proxy_utils, :forwarder, ProxyUtils.Forwarders.Direct

config :proxy_utils, :connector, ProxyUtils.Connectors.PassThrough
config :proxy_utils, :connector_conf, perform_dns: true

config :proxy_utils, :recv_timeout, 5000

config :proxy_utils, :ip, {127, 0, 0, 1}

config :proxy_utils, :port, 2030

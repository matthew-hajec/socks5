import Config

config :proxy_utils, :forwarder, ProxyUtils.Forwarders.Direct

config :proxy_utils, :connector, ProxyUtils.Connectors.PassThrough
config :proxy_utils, :connector_opts, %{proxy: {~c"127.0.0.1", ~c"9050"}}

config :proxy_utils, :recv_timeout, 5000

config :proxy_utils, :ip, {127, 0, 0, 1}

# config :socks5, :port, 1080

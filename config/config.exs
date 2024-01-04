import Config

config :socks5, :forwarder, Socks5.Forwarders.Direct

config :socks5, :connector, Socks5.Connectors.PassThrough
config :socks5, :connector_opts, %{proxy: {~c"127.0.0.1", ~c"9050"}}

config :socks5, :recv_timeout, 5000

config :socks5, :ip, {127, 0, 0, 1}

# config :socks5, :port, 1080

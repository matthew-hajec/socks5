defmodule Socks5.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_port 2030

  def open_observer do
    Mix.ensure_application!(:wx)
    Mix.ensure_application!(:runtime_tools)
    Mix.ensure_application!(:observer)
    :observer.start()
  end

  @impl true
  def start(_type, _args) do
    open_observer()

    children = [
      # Start and supervise the connector
      Supervisor.child_spec({connector(), connector_opts()}, restart: :permanent),
      {Task.Supervisor, [name: Socks5.TaskSupervisor]},
      # This supervisor doesn't NEED to exist, since it's not a huge deal if a forwarder dies, but it's nice for debugging.
      {Task.Supervisor, [name: Socks5.ForwarderSupervisor]},
      Supervisor.child_spec({Task, fn -> Socks5.Server.start(port()) end}, restart: :permanent)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Socks5.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def port do
    Application.get_env(:socks5, :port) || @default_port
  end

  def connector do
    Application.get_env(:socks5, :connector)
  end

  def connector_opts do
    Application.get_env(:socks5, :connector_opts)
  end
end

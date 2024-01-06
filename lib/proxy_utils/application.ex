defmodule ProxyUtils.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_port 2030

  defp open_observer do
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
      {Task.Supervisor, [name: ProxyUtils.TaskSupervisor]},
      # This supervisor doesn't NEED to exist, since it's not a huge deal if a forwarder dies, but it's nice for debugging.
      {Task.Supervisor, restart: :temporary, name: ProxyUtils.ForwarderSupervisor},
      Supervisor.child_spec({Task, fn -> ProxyUtils.Server.start(port()) end},
        restart: :permanent
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ProxyUtils.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port do
    Application.get_env(:proxy_utils, :port) || @default_port
  end

  defp connector do
    Application.get_env(:proxy_utils, :connector)
  end

  defp connector_opts do
    Application.get_env(:proxy_utils, :connector_opts)
  end
end

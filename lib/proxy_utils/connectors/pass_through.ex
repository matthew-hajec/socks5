defmodule ProxyUtils.Connectors.PassThrough do
  @moduledoc """
  A connector that simply returns a socket that is connected to the given location and port.
  """

  require Logger
  use GenServer

  # Public API
  def connect(location) do
    case GenServer.call(__MODULE__, {:get_connector, location}) do
      {:ok, connector} ->
        connector.()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, opts}
  end

  def handle_call({:get_connector, location}, _from, state) do
    # Return a function that, when called, will connect to the given location and port
    connector = fn ->


      perform_dns = Keyword.get(state, :perform_dns, false)

      Logger.debug("Connecting to #{inspect(location)} (perform DNS: #{inspect(perform_dns)})")

      connect_to_location(location, perform_dns)
    end

    {:reply, {:ok, connector}, state}
  end

  defp connect_to_location(location, perform_dns) do
    location =
      if location.type == :domain and perform_dns do
        {:ok , {ip, type}} = resolve(location.host)
        %{location | host: ip, type: type}
      else
        location
      end

    :gen_tcp.connect(location.host, location.port, [:binary, active: false])
  end

  defp resolve(hostname) do
    case :inet.gethostbyname(to_charlist(hostname)) do
      {:ok, {:hostent, _name, _alias, _addrtype, _length, addr_list}} ->
        first = addr_list |> List.first()
        Logger.debug("Resolved #{inspect(hostname)} to #{inspect(first)}")

        if tuple_size(first) == 4 do
          {:ok, {first, :ipv4}}
        else
          {:ok, {first, :ipv6}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

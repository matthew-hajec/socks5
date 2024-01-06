defmodule ProxyUtils.Connectors.DNS do
  @moduledoc """
  A connector that simply returns a socket that is connected to the given location and port.

  If the location is a domain, it will be resolved to an IP address.
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

  def init(_opts) do
    {:ok, nil}
  end

  def handle_call({:get_connector, location}, from, nil) do
    # Return a function that, when called, will connect to the given location and port
    connector = fn ->
      Logger.debug("Connecting to #{inspect(location)}")

      #If the location is a domain, resolve it to an IP address
      #otherwise, just use the location as-is
      location = case location.type do
        :domain ->
          %{location | host: resolve(location.host) |> List.first }

        _ ->
          location
      end

      case :gen_tcp.connect(location.host, location.port, [:binary, active: false]) do
        {:ok, socket} ->
          # Print the remote server ip address
          Logger.debug("Connected to #{inspect(:inet.peername(socket))}")
          # Give the socket to the caller
          {pid, _ref} = from
          :gen_tcp.controlling_process(socket, pid)
          {:ok, socket}

        {:error, reason} ->
          {:error, reason}
      end
    end

    {:reply, {:ok, connector}, nil}
  end

  def resolve(hostname) do
    {:ok, {:hostent, _name, _alias, _addrtype, _length, addr_list}} = :inet.gethostbyname(to_charlist(hostname))

    addr_list
    |> Enum.map(&format_ip/1)
  end

  defp format_ip(ip) when is_tuple(ip) and tuple_size(ip) == 4 do
    Tuple.to_list(ip) |> Enum.join(".")
  end

  defp format_ip(ip) when is_tuple(ip) and tuple_size(ip) == 8 do
    ip
    |> Tuple.to_list()
    |> Enum.map(&Integer.to_string/1)
    |> Enum.join(":")
  end
end

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

  def init(_opts) do
    {:ok, nil}
  end

  def handle_call({:get_connector, location}, from, nil) do
    # Return a function that, when called, will connect to the given location and port
    connector = fn ->
      Logger.debug("Connecting to #{inspect(location)}")

      # If the location is a domain, return an error
      if location.type == :domain do
        {:error, :domain_not_supported}
      end

      case :gen_tcp.connect(location.host, location.port, [:binary, active: false]) do
        {:ok, socket} ->
          # Give the socket to the
          {pid, _ref} = from
          :gen_tcp.controlling_process(socket, pid)
          {:ok, socket}

        {:error, reason} ->
          {:error, reason}
      end
    end

    {:reply, {:ok, connector}, nil}
  end
end

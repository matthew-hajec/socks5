defmodule ProxyUtils.Forwarders.Direct do
  @moduledoc """
  A forwarder that simply forwards data from one socket to another.
  """

  @doc """
  Forwards data from one socket to another.

  Stops forwarding when an error occurs or the socket is closed.

  Returns `:ok` once the socket is ensured to be closed.
  """
  @behaviour ProxyUtils.Behaviours.Forwarder
  require Logger

  def tcp(from, to, client) do
    with {:ok, data} <- :gen_tcp.recv(from, 0, ProxyUtils.Config.recv_timeout()),
         :ok <- :gen_tcp.send(to, data) do
      tcp(from, to, client)
    else
      {:error, reason} ->
        Logger.debug("Forwarding stopped: #{inspect(reason)}")
        :gen_tcp.close(from)
        :gen_tcp.close(to)
    end
  end
end

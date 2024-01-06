defmodule ProxyUtils.Forwarders.Direct do
  @moduledoc """
  A forwarder that simply forwards data from one socket to another.
  """

  @doc """
  Forwards data from one socket to another.

  Stops forwarding when an error occurs or the socket is closed.

  Returns `:ok` once the socket is ensured to be closed.
  """
  require Logger
  def tcp(from, to) do
    with {:ok, data} <- :gen_tcp.recv(from, 0),
         :ok <- :gen_tcp.send(to, data) do
      tcp(from, to)
    else
      {:error, reason} ->
        ProxyUtils.SocketUtil.close_socket(from, reason)
    end
  end
end

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
    Logger.debug("Forwarding data from #{inspect(:inet.peername(from))} to #{inspect(:inet.peername(to))}")

    try do
      with {:ok, data} <- :gen_tcp.recv(from, 0, ProxyUtils.Config.recv_timeout()),
           :ok <- :gen_tcp.send(to, data) do
        # append the data to the message buffer (remove null bytes)
        tcp(from, to)
      else
        {:error, reason} ->
          ProxyUtils.SocketUtil.close_socket(from, reason)
        end
    catch
      :exit, _ ->
        Logger.debug("Forwarding stopped: socket closed")
        ProxyUtils.SocketUtil.close_socket(from, :normal)
      end
  end
end

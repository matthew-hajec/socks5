defmodule ProxyUtils.SocketUtil do
  @moduledoc """
  Utility functions for working with sockets.
  """

  require Logger

  @doc """
  Closes a socket and logs the reason if provided.

  ## Parameters

  - `socket`: The socket to close.
  - `reason`: An optional reason for closing the socket. If provided, it will be converted to a string using `inspect/1` and logged as a debug message.

  ## Side Effects

  - If a reason is provided, a debug message will be logged with the reason,
  - The socket will be closed.

  ## Returns

  - `:ok` if the socket is successfully closed.
  """
  def close_socket(socket, reason \\ nil) do
    case reason do
      nil -> :ok
      :closed -> :ok
      :timeout -> :ok
      _ -> Logger.debug("Closing socket: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end
end

defmodule ProxyUtils.Forwarder do
  @moduledoc """
  A forwarder is responsible for forwarding data from one socket to another.

  The forwarder is given two sockets and is expected to forward data from one socket to the other.
  """

  @callback tcp(any(), any()) :: :ok | {:error, any()}
end

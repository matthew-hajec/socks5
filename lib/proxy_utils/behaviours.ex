defmodule ProxyUtils.Behaviours do
  @moduledoc """
  Defines behaviours for the proxy.
  """

  defmodule Connector do
    @moduledoc """
    A connector is responsible for connecting to the remote server.

    The connector is given a location and is expected to return a socket that is connected to the
    remote server.
    """
    @callback connect(ProxyUtils.Location.t()) :: {:ok, any()} | {:error, any()}
  end

  defmodule Forwarder do
    @moduledoc """
    A forwarder is responsible for forwarding data from one socket to another.

    The forwarder is given two sockets and is expected to forward data from one socket to the other.
    """

    @callback tcp(any(), any()) :: :ok | {:error, any()}
  end
end

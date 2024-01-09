defmodule ProxyUtils.Connector do
  @moduledoc """
  A connector is responsible for connecting to the remote server.

  The connector is given a location and is expected to return a socket that is connected to the
  remote server.
  """

  @callback connect(ProxyUtils.Location.t()) :: {:ok, any()} | {:error, any()}
end

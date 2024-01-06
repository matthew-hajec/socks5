defmodule ProxyUtils.Location do
  @moduledoc """
  Provides struct for location.
  """
  # :host <- Domain or IP address
  # :port <- Port number
  # :type <- :ipv4, :ipv6, or :domain
  defstruct [:host, :port, :type]
end

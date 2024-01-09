defmodule ProxyUtils.Config do
  @moduledoc """
  Provides access to configuration values.
  """

  @doc """
  Returns the IP address to listen on.
  """
  def ip, do: Application.get_env(:proxy_utils, :ip)

  @doc """
  Returns the port to listen on.
  """
  def port, do: Application.get_env(:proxy_utils, :port)

  @doc """
  Returns the forwarder module.
  """
  def forwarder, do: Application.get_env(:proxy_utils, :forwarder)

  @doc """
  Returns the connector module.
  """
  def connector, do: Application.get_env(:proxy_utils, :connector)

  @doc """
  Returns the connector options.
  """
  def connector_conf, do: Application.get_env(:proxy_utils, :connector_conf)

  @doc """
  Returns the receive timeout.
  """
  def recv_timeout, do: Application.get_env(:proxy_utils, :recv_timeout)
end

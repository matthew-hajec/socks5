defmodule ProxyUtils.Client do
  @moduledoc """
  Defines the client struct.
  """

  # :socket <- The socket connected to the client.
  # :origin_addr <- The address of the client. {ip, port}
  # :remote_location <- The location the client wants to connect to. (Location struct)
  # :metadata <- Custom metadata about the client. #{key => value}

  defstruct [:socket, :origin_addr, :remote_location, :username, :metadata]

  def new(socket, origin_addr) do
    %ProxyUtils.Client{
      socket: socket,
      origin_addr: origin_addr,
      remote_location: nil,
      username: nil,
      metadata: %{}
    }
  end
end

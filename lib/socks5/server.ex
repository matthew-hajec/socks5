defmodule Socks5.Server do
  @moduledoc """
  The main entry point for the SOCKS5 server.

  This module is responsible for starting the server and handling client connections.
  """
  require Logger

  @doc """
  Starts the SOCKS5 server on the given port.

  ## Parameters

  - `port`: The port to listen on.

  ## Side Effects

  - Logs a message to the console when the server starts.

  ## Returns

  - :no_return (the acceptorr runs until it is stopped or crashes)
  """
  def start(port) do
    {:ok, socket} = :gen_tcp.listen(port, active: false, reuseaddr: true)
    Logger.info("Proxy listening on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    with {:ok, client} <- :gen_tcp.accept(socket),
         {:ok, {ip, port}} <- :inet.peername(client), # For logging
         :ok <-
           start_client_task(client) do
      Logger.debug("Accepted connection from #{inspect(ip)}:#{inspect(port)}")
    else
      {:error, reason} ->
        Logger.debug("Error accepting connection: #{inspect(reason)}")
    end

    loop_acceptor(socket)
  end

  defp start_client_task(client) do
    case Task.Supervisor.start_child(Socks5.TaskSupervisor, fn -> handle_client(client) end) do
      {:ok, pid} ->
        :gen_tcp.controlling_process(client, pid)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles a client connection.

  Returns `:ok` if the client is handled successfully, or `{:error, reason}` if an error occurs.
  """
  def handle_client(client) do
    with :ok <- handshake(client),
         :ok <- handle_request(client) do
      :ok
    else
      {:error, :closed} ->
        :ok

      {:error, reason} ->
        Logger.debug("Error handling client: #{inspect(reason)}")
        Socks5.SocketUtil.close_socket(client)
        {:error, reason}
    end
  end

  @doc """
  Handles the introduction/authentication for the SOCKS5 protocol.

  Returns `:ok` if the client is authenticated, or `{:error, reason}` if an error occurs.
  """
  def handshake(client) do
    with {:ok, [5]} <- :gen_tcp.recv(client, 1, recv_timeout()),
         {:ok, [nmethods]} <- :gen_tcp.recv(client, 1, recv_timeout()),
         {:ok, methods} <- :gen_tcp.recv(client, nmethods, recv_timeout()),
         :ok <- authenticate(select_auth_method(methods), client) do
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Selects the first supported method from the list of methods.

  If no methods are supported, it returns 0xFF, which is Socks5 speak for "no acceptable methods".
  """
  def select_auth_method(methods) do
    Enum.find(methods, fn m -> m in [0] end) || 255
  end

  @doc """
  Authenticates the client using the given method.

  Returns `:ok` if the client is authenticated, or `{:error, reason}` if an error occurs.
  """
  def authenticate(0, client) do
    # No authentication required
    case :gen_tcp.send(client, <<5, 0>>) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def authenticate(255, client) do
    # Unsupported authentication method
    case :gen_tcp.send(client, <<5, 255>>) do
      :ok ->
        {:error, :no_supported_authentication}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles a SOCKS5 request from the client.

  Returns `:ok` if the request is handled successfully, or `{:error, reason}` if an error occurs.
  """
  def handle_request(client) do
    case :gen_tcp.recv(client, 4, recv_timeout()) do
      {:ok, request} ->
        {:ok, {location, port}} = get_destination(request, client)
        [5, cmd, _rsv, atyp] = request

        case cmd do
          1 ->
            cmd_connect(client, {location, port}, atyp)

          2 ->
            reply_error(client, 7, atyp)
            {:error, :command_not_supported}

          3 ->
            reply_error(client, 7, atyp)
            {:error, :command_not_supported}

          4 ->
            reply_error(client, 7, atyp)
            {:error, :command_not_supported}

          _ ->
            reply_error(client, 7, atyp)
            {:error, :unknown_command}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reads the destination address from the client.

  Returns `{:ok, {location, port}}` if the address is read successfully, or `{:error, reason}` if an error occurs.
  """
  def get_destination(request, client) do
    case request do
      [5, _cmd, _rsv, 1] ->
        get_ipv4(client)

      [5, _cmd, _rsv, 3] ->
        get_domain(client)

      [5, _cmd, _rsv, 4] ->
        get_ipv6(client)

      _ ->
        Logger.debug("Unknown address type from request: #{inspect(request)}")
        Socks5.SocketUtil.close_socket(client)
        {:error, :unknown_address_type}
    end
  end

  @doc """
  Reads the IPv4 address from the client.

  Returns `{:ok, {ip, port}}` if the address is read successfully, or `{:error, reason}` if an error occurs.
  """
  def get_ipv4(client) do
    # Reformat with a with statment
    with {:ok, [ip1, ip2, ip3, ip4]} <- :gen_tcp.recv(client, 4, recv_timeout()),
         {:ok, [port1, port2]} <- :gen_tcp.recv(client, 2, recv_timeout()) do
      ip = ~c"#{ip1}.#{ip2}.#{ip3}.#{ip4}"
      port = port1 * 256 + port2
      {:ok, {ip, port}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reads the destination domain name from the client.

  Returns `{:ok, {domain, port}}` if the domain is read successfully, or `{:error, reason}` if an error occurs.
  """
  def get_domain(client) do
    with {:ok, [len]} <- :gen_tcp.recv(client, 1, recv_timeout()),
         {:ok, domain} <- :gen_tcp.recv(client, len, recv_timeout()),
         {:ok, [port1, port2]} <- :gen_tcp.recv(client, 2, recv_timeout()) do
      port = port1 * 256 + port2
      # Convert domain to a charlist
      domain = String.to_charlist(domain)
      {:ok, {domain, port}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reads the destination IPv6 address from the client.

  Returns `{:ok, {ip, port}}` if the address is read successfully, or `{:error, reason}` if an error occurs.
  """
  def get_ipv6(client) do
    with {:ok, octets} <- :gen_tcp.recv(client, 16, recv_timeout()),
         {:ok, [port1, port2]} <- :gen_tcp.recv(client, 2, recv_timeout()) do
      ip = Enum.map_join(octets, ":", fn octet -> Integer.to_string(octet, 16) end)
      port = port1 * 256 + port2

      ip = String.to_charlist(ip)
      {:ok, {ip, port}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Performs the command requested by the client.

  Returns `:ok` if the command is performed successfully, or `{:error, reason}` if an error occurs.
  """
  def cmd_connect(client, {location, port}, atyp) do
    with {:ok, socket} <- connector().connect(location, port),
         :ok <- reply_success(client, atyp) do
      # Start the two forwarders (one for each direction)
      {:ok, forwarder1} =
        Task.Supervisor.start_child(Socks5.ForwarderSupervisor, fn ->
          forwarder().tcp(client, socket, recv_timeout())
        end)

      {:ok, forwarder2} =
        Task.Supervisor.start_child(Socks5.ForwarderSupervisor, fn ->
          forwarder().tcp(socket, client, recv_timeout())
        end)

      # Set the controlling process for each socket
      with :ok <- :gen_tcp.controlling_process(socket, forwarder1),
           :ok <- :gen_tcp.controlling_process(client, forwarder2) do
        :ok
      else
        {:error, reason} ->
          reply_error(client, 1, atyp)
          {:error, reason}
      end
    else
      {:error, reason} ->
        reply_error(client, 1, atyp)
        {:error, reason}
    end
  end

  @doc """
  Replies to the client with an error message.

  Returns `:ok` if the reply is sent successfully, or `{:error, reason}` if an error occurs.
  """
  def reply_error(client, error_code, atyp) do
    :gen_tcp.send(client, <<5, error_code, 0, atyp, 0, 0, 0, 0, 0, 0>>)
  end

  @doc """
  Replies to the client with a success message.

  Returns `:ok` if the reply is sent successfully, or `{:error, reason}` if an error occurs.
  """
  def reply_success(client, atyp) do
    :gen_tcp.send(client, <<5, 0, 0, atyp, 0, 0, 0, 0, 0, 0>>)
  end

  def forwarder() do
    Application.get_env(:socks5, :forwarder)
  end

  def connector() do
    Application.get_env(:socks5, :connector)
  end

  def recv_timeout() do
    Application.get_env(:socks5, :recv_timeout)
  end
end

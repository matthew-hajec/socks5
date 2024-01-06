defmodule ProxyUtils.Server do
  @moduledoc """
  The main entry point for the SOCKS5 server.

  This module is responsible for starting the server and handling client connections.
  """
  alias ElixirSense.Log
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
         # For logging
         {:ok, {ip, port}} <- :inet.peername(client),
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
    case Task.Supervisor.start_child(ProxyUtils.TaskSupervisor, fn -> handle_client(client) end) do
      {:ok, pid} ->
        :gen_tcp.controlling_process(client, pid)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_client(client) do
    with :ok <- handshake(client),
         :ok <- handle_request(client) do
      :ok
    else
      {:error, :closed} ->
        :ok

      {:error, reason} ->
        Logger.debug("Error handling client: #{inspect(reason)}")
        ProxyUtils.SocketUtil.close_socket(client)
        {:error, reason}
    end
  end

  defp handshake(client) do
    with {:ok, [5]} <- :gen_tcp.recv(client, 1, ProxyUtils.Config.recv_timeout()),
         {:ok, [nmethods]} <- :gen_tcp.recv(client, 1, ProxyUtils.Config.recv_timeout()),
         {:ok, methods} <- :gen_tcp.recv(client, nmethods, ProxyUtils.Config.recv_timeout()),
         :ok <- authenticate(select_auth_method(methods), client) do
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp select_auth_method(methods) do
    # Return the first supported method or 255 if none are supported

    Enum.find(methods, fn m -> m end) || 255
  end

  defp authenticate(method, client) do
    Logger.debug("Authenticating with method #{inspect(method)}")

    case method do
      0 ->
        auth_none(client)

      2 ->
        auth_username_password(client)

      _ ->
        auth_unsupported(client)
    end
  end

  defp auth_none(client) do
    # No authentication required
    case :gen_tcp.send(client, <<5, 0>>) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_username_password(client) do
    # Username/password authentication defined in RFC 1929
    with :ok <- :gen_tcp.send(client, <<5, 2>>),
         {:ok, [1, ulen]} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()),
         {:ok, username} <- :gen_tcp.recv(client, ulen, ProxyUtils.Config.recv_timeout()),
         {:ok, [plen]} <- :gen_tcp.recv(client, 1, ProxyUtils.Config.recv_timeout()),
         {:ok, password} <- :gen_tcp.recv(client, plen, ProxyUtils.Config.recv_timeout()) do
      Logger.debug("Authenticating with username #{inspect(username)} and password #{inspect(password)}")
      if username == ~c"user" && password == ~c"pass" do
        :gen_tcp.send(client, <<1, 0>>)
        :ok
      else
        :gen_tcp.send(client, <<1, 1>>)
        {:error, :authentication_failed}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_unsupported(client) do
    # Unsupported authentication method
    case :gen_tcp.send(client, <<5, 255>>) do
      :ok ->
        {:error, :no_supported_authentication}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_request(client) do
    case :gen_tcp.recv(client, 4, ProxyUtils.Config.recv_timeout()) do
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

  defp get_destination(request, client) do
    case request do
      [5, _cmd, _rsv, 1] ->
        get_ipv4(client)

      [5, _cmd, _rsv, 3] ->
        get_domain(client)

      [5, _cmd, _rsv, 4] ->
        get_ipv6(client)

      _ ->
        Logger.debug("Unknown address type from request: #{inspect(request)}")
        ProxyUtils.SocketUtil.close_socket(client)
        {:error, :unknown_address_type}
    end
  end

  defp get_ipv4(client) do
    # Reformat with a with statment
    with {:ok, [ip1, ip2, ip3, ip4]} <-
           :gen_tcp.recv(client, 4, ProxyUtils.Config.recv_timeout()),
         {:ok, [port1, port2]} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()) do
      ip = ~c"#{ip1}.#{ip2}.#{ip3}.#{ip4}"
      port = port1 * 256 + port2
      {:ok, {ip, port}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_domain(client) do
    with {:ok, [len]} <- :gen_tcp.recv(client, 1, ProxyUtils.Config.recv_timeout()),
         {:ok, domain} <- :gen_tcp.recv(client, len, ProxyUtils.Config.recv_timeout()),
         {:ok, [port1, port2]} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()) do
      port = port1 * 256 + port2
      # Convert domain to a charlist
      domain = String.to_charlist(domain)
      {:ok, {domain, port}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_ipv6(client) do
    with {:ok, octets} <- :gen_tcp.recv(client, 16, ProxyUtils.Config.recv_timeout()),
         {:ok, [port1, port2]} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()) do
      ip = Enum.map_join(octets, ":", fn octet -> Integer.to_string(octet, 16) end)
      port = port1 * 256 + port2

      ip = String.to_charlist(ip)
      {:ok, {ip, port}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cmd_connect(client, {location, port}, atyp) do
    forwarder = ProxyUtils.Config.forwarder()
    connector = ProxyUtils.Config.connector()

    with {:ok, socket} <- connector.connect(location, port),
         :ok <- reply_success(client, atyp),
         {:ok, forwarder1} <-
           Task.Supervisor.start_child(ProxyUtils.ForwarderSupervisor, fn ->
             forwarder.tcp(client, socket, ProxyUtils.Config.recv_timeout())
           end),
         {:ok, forwarder2} <-
           Task.Supervisor.start_child(ProxyUtils.ForwarderSupervisor, fn ->
             forwarder.tcp(socket, client, ProxyUtils.Config.recv_timeout())
           end),
         :ok <- :gen_tcp.controlling_process(socket, forwarder1),
         :ok <- :gen_tcp.controlling_process(client, forwarder2) do
      :ok
    else
      {:error, reason} ->
        reply_error(client, 1, atyp)
        {:error, reason}
    end
  end

  defp reply_error(client, error_code, atyp) do
    :gen_tcp.send(client, <<5, error_code, 0, atyp, 0, 0, 0, 0, 0, 0>>)
  end

  defp reply_success(client, atyp) do
    :gen_tcp.send(client, <<5, 0, 0, atyp, 0, 0, 0, 0, 0, 0>>)
  end
end

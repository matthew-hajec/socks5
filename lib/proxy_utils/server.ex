defmodule ProxyUtils.Server do
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
  def start(ip, port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, ip: ip, active: false, reuseaddr: true])
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
        :gen_tcp.close(client)
        {:error, reason}
    end
  end

  defp handshake(client) do
    with {:ok, <<5, nmethods>>} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()),
         {:ok, methods_bin} <- :gen_tcp.recv(client, nmethods, ProxyUtils.Config.recv_timeout()),
         methods = :binary.bin_to_list(methods_bin),
         :ok <- authenticate(List.first(methods), client) do
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp authenticate(method, client) do
    {:ok, {ip, port}} = :inet.peername(client)

    Logger.debug("#{inspect(ip)}:#{inspect(port)} authenticating with method #{inspect(method)}")

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
         {:ok, <<1, ulen>>} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()),
         {:ok, username} <- :gen_tcp.recv(client, ulen, ProxyUtils.Config.recv_timeout()),
         {:ok, <<plen>>} <- :gen_tcp.recv(client, 1, ProxyUtils.Config.recv_timeout()),
         {:ok, password} <- :gen_tcp.recv(client, plen, ProxyUtils.Config.recv_timeout()) do
      Logger.debug(
        "Authenticating with username #{inspect(username)} and password #{inspect(password)}"
      )

      if username == "user" && password == "pass" do
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
        <<5, cmd, _rsv, atyp>> = request

        {:ok, location} = get_destination(atyp, client)

        case cmd do
          1 ->
            cmd_connect(client, location)

          _ ->
            reply_error(client, 7)
            {:error, :unknown_command}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_destination(atyp, client) do
    case atyp do
      1 ->
        get_ipv4(client)

      3 ->
        get_domain(client)

      4 ->
        get_ipv6(client)

      _ ->
        {:error, :unknown_address_type}
    end
  end

  defp get_ipv4(client) do
    with {:ok, <<a, b, c, d>>} <- :gen_tcp.recv(client, 4, ProxyUtils.Config.recv_timeout()),
         {:ok, <<port::16>>} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()) do
      ip = {a, b, c, d}

      {:ok, %ProxyUtils.Location{host: ip, port: port, type: :ipv4}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_domain(client) do
    with {:ok, <<len>>} <- :gen_tcp.recv(client, 1, ProxyUtils.Config.recv_timeout()),
         {:ok, domain} <- :gen_tcp.recv(client, len, ProxyUtils.Config.recv_timeout()),
         {:ok, <<port::16>>} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()) do
      {:ok, %ProxyUtils.Location{host: domain, port: port, type: :domain}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_ipv6(client) do
    with {:ok, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>} <-
           :gen_tcp.recv(client, 16, ProxyUtils.Config.recv_timeout()),
         {:ok, <<port::16>>} <- :gen_tcp.recv(client, 2, ProxyUtils.Config.recv_timeout()) do
      ip = {a, b, c, d, e, f, g, h}

      {:ok, %ProxyUtils.Location{host: ip, port: port, type: :ipv6}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cmd_connect(client, location) do
    forwarder = ProxyUtils.Config.forwarder()
    connector = ProxyUtils.Config.connector()

    with {:ok, socket} <- connector.connect(location),
         :ok <- reply_success(client),
         {:ok, forwarder1} <-
           Task.Supervisor.start_child(ProxyUtils.ForwarderSupervisor, fn ->
             forwarder.tcp(client, socket)
           end),
         {:ok, forwarder2} <-
           Task.Supervisor.start_child(ProxyUtils.ForwarderSupervisor, fn ->
             forwarder.tcp(socket, client)
           end),
         :ok <- :gen_tcp.controlling_process(client, forwarder1),
         :ok <- :gen_tcp.controlling_process(socket, forwarder2) do
      Logger.debug(
        "Bidirectional forwarding established data between #{inspect(:inet.peername(client))} and #{inspect(:inet.peername(socket))}"
      )

      :ok
    else
      {:error, reason} ->
        reply_error(client, 1)
        {:error, reason}
    end
  end

  defp reply_error(client, error_code) do
    :gen_tcp.send(client, <<5, error_code, 0, 1, 0::32, 0::16>>)
  end

  defp reply_success(client) do
    :gen_tcp.send(client, <<5, 0, 0, 1, 0::32, 0::16>>)
  end
end

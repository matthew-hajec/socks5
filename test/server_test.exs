defmodule ServerTest do
  require Logger
  use ExUnit.Case

  test "accepts incoming TCP connections on the configured port" do
    ip = ProxyUtils.Config.ip()
    port = ProxyUtils.Config.port()

    Logger.debug("Connecting to #{inspect(ip)}:#{inspect(port)}")

    {:ok, client} = :gen_tcp.connect(ip, port, active: false)
  end

  test "accepts no auth" do
    ip = ProxyUtils.Config.ip()
    port = ProxyUtils.Config.port()

    Logger.debug("Connecting to #{inspect(ip)}:#{inspect(port)}")

    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])

    Logger.debug("Sending data to #{inspect(ip)}:#{inspect(port)}")

    :gen_tcp.send(client, <<5, 1, 0>>)

    # print the response
    Logger.debug("Receiving data from #{inspect(ip)}:#{inspect(port)}")
    {:ok, <<5, 0>>} = :gen_tcp.recv(client, 0, ProxyUtils.Config.recv_timeout())
  end

  test "accepts username/password auth" do
    ip = ProxyUtils.Config.ip()
    port = ProxyUtils.Config.port()


    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])


    :gen_tcp.send(client, <<5, 1, 2>>)

    # print the response
    {:ok, <<5, 2>>} = :gen_tcp.recv(client, 0, ProxyUtils.Config.recv_timeout())


    username = "user"
    password = "pass"

    :gen_tcp.send(client, <<1, 4, username::binary, 4, password::binary>>)

    # print the response
    {:ok, <<1, 0>>} = :gen_tcp.recv(client, 0, ProxyUtils.Config.recv_timeout())
  end

  test "returns 255 when the client provides no supported auth protocol" do
    ip = ProxyUtils.Config.ip()
    port = ProxyUtils.Config.port()

    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])

    # If any auth protocol uses 254, this test will fail.
    # This is unlikely, but possible, just change the number if this test fails as a result.
    :gen_tcp.send(client, <<5, 1, 254>>)

    {:ok, <<5, 255>>} = :gen_tcp.recv(client, 0, ProxyUtils.Config.recv_timeout())
  end

  test "closes connection if client sends a different socks version" do
    ip = ProxyUtils.Config.ip()
    port = ProxyUtils.Config.port()

    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false])

    :gen_tcp.send(client, <<4, 1, 0>>)

    {:error, :closed} = :gen_tcp.recv(client, 0, ProxyUtils.Config.recv_timeout())
  end
end

defmodule ForwardersTest do
  use ExUnit.Case

  test "performs direct forwarding" do
    # Open 2 sockets
    {:ok, server} = :gen_tcp.listen(0, active: false, reuseaddr: true)
    {:ok, port} = :inet.port(server)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, active: false)

    # Forward data sent from the client to the server
    {:ok, _pid} =
      Task.Supervisor.start_child(ProxyUtils.TaskSupervisor, fn ->
        ProxyUtils.Forwarders.Direct.tcp(client, server, 100)
      end)

    # Send some data from the client
    :gen_tcp.send(client, ~c"Hello, world!")

    # Sleep for a bit to give the forwarder time to forward the data
    Process.sleep(100)

    # Accept a connection on the server
    {:ok, conn} = :gen_tcp.accept(server)

    # Receive the data from the connection
    {:ok, data} = :gen_tcp.recv(conn, 0, 100)

    # Check that the data is the same
    assert data == ~c"Hello, world!"
  end
end

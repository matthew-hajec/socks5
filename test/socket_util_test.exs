defmodule SocketUtilTest do
  use ExUnit.Case

  test "closes a socket" do
    {:ok, socket} = :gen_tcp.listen(0, active: false, reuseaddr: true)

    Socks5.SocketUtil.close_socket(socket)
    assert :gen_tcp.close(socket) == :ok
  end

  test "returns :ok when passed a closed socket" do
    {:ok, socket} = :gen_tcp.listen(0, active: false, reuseaddr: true)

    assert Socks5.SocketUtil.close_socket(socket) == :ok
    assert Socks5.SocketUtil.close_socket(socket) == :ok
  end
end

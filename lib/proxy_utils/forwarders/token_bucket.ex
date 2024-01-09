defmodule ProxyUtils.Forwarders.TokenBucket do
  @moduledoc """
  A forwarder that simply forwards data from one socket to another.
  """

  @doc """
  Forwards data from one socket to another.

  Stops forwarding when an error occurs or the socket is closed.

  Returns `:ok` once the socket is ensured to be closed.
  """
  @behaviour ProxyUtils.Behaviours.Forwarder
  require Logger

  @bitspersecond 25_000_000
  @buckettime 100
  @tokentimeout 5000

  def tcp(from, to) do
    # Check if there are enough tokens in the bucket
    with {:ok, data} <- :gen_tcp.recv(from, 0, ProxyUtils.Config.recv_timeout()),
         :ok <- wait_for_bandwidth("total_tcp", @buckettime, trunc(@bitspersecond * @buckettime / 1000), byte_size(data) * 8, @tokentimeout),
         :ok <- :gen_tcp.send(to, data) do
      tcp(from, to)
    else
      {:error, reason} ->
        Logger.debug("Forwarding stopped: #{inspect(reason)}")
        :gen_tcp.close(from)
        :gen_tcp.close(to)
    end
  end

  defp wait_for_bandwidth(id, scale_ms, limit, increment, timeout) do
    start_tm = :os.system_time(:millisecond)
    wait_for_bandwidth(id, scale_ms, limit, increment, timeout, start_tm)
  end

  defp wait_for_bandwidth(id, scale_ms, limit, increment, timeout, start_tm) do
    case Hammer.check_rate_inc("total", scale_ms, limit, increment) do
      {:allow, _} ->
        :ok

      {:deny, _} ->
        Logger.error("Denied, it has been #{:os.system_time(:millisecond) - start_tm})")

        if :os.system_time(:millisecond) - start_tm > timeout do
          Logger.error("Bandwidth timeout for #{id}")
          {:error, :bandwidth_timeout}
        else
          wait_for_bandwidth(id, scale_ms, limit, increment, timeout, start_tm)
        end
    end
  end
end

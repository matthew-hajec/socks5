defmodule ProxyUtils.Connectors.PassThrough do
  @moduledoc """
  A connector that simply returns a socket that is connected to the given location and port.
  """
  @behaviour ProxyUtils.Behaviours.Connector
  require Logger

  @conf ProxyUtils.Config.connector_conf()

  def connect(%ProxyUtils.Location{host: domain_name, port: port, type: :domain} = _location) do
    perform_dns = Keyword.get(@conf, :perform_dns, false)

    if perform_dns do
      case resolve(domain_name) do
        {:ok, {ip, _type}} ->
          :gen_tcp.connect(ip, port, [:binary, active: false])

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :dns_disabled}
    end
  end

  def connect(%ProxyUtils.Location{host: ip, port: port, type: _type} = _location) do
    :gen_tcp.connect(ip, port, [:binary, active: false])
  end

  defp resolve(hostname)
       when is_binary(hostname) do
    case :inet.gethostbyname(to_charlist(hostname)) do
      {:ok, {:hostent, _name, _alias, _addrtype, _length, addr_list}} ->
        first = addr_list |> List.first()
        Logger.debug("Resolved #{inspect(hostname)} to #{inspect(first)}")

        if tuple_size(first) == 4 do
          {:ok, {first, :ipv4}}
        else
          {:ok, {first, :ipv6}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

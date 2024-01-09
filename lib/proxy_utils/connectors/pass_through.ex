defmodule ProxyUtils.Connectors.PassThrough do
  @moduledoc """
  A connector that simply returns a socket that is connected to the given location and port.
  """
  require Logger

  @conf ProxyUtils.Config.connector_conf()

  def connect(%ProxyUtils.Location{host: domain_name, port: port, type: :domain} = _location)
  when is_binary(domain_name) and is_integer(port)
  do
    perform_dns = Keyword.get(@conf, :perform_dns, false)

    if perform_dns do
      {:ok , {ip, _type}} = resolve(domain_name)
      :gen_tcp.connect(ip, port, [:binary, active: false])
    else
      {:error, :dns_disabled}
    end
  end

  def connect(%ProxyUtils.Location{host: ip, port: port, type: _type} = _location)
  when is_tuple(ip) and is_integer(port)
  do
    :gen_tcp.connect(ip, port, [:binary, active: false])
  end


  defp resolve(hostname)
  when is_binary(hostname)
  do
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

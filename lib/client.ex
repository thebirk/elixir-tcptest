defmodule Client do
  require Logger
  use GenServer

  @initialState %{
    socket: nil,
    name: nil
  }

  def start_link(socket, opts \\ []) do
    GenServer.start_link(__MODULE__, socket, opts)
  end

  def init(socket) do
    name = get_client_name(socket)
    Logger.info "Client connected from #{name}"
    {:ok, %{@initialState | socket: socket, name: name}}
  end

  def handle_info({:tcp, _socket, data}, %{name: name} = state) do
    Logger.info "Message '#{data |> String.replace("\n", "\\n") |> String.replace("\r", "\\r")}' from #{name}"
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{name: name} = state) do
    Logger.info "Closing connection from #{name}"
    Process.exit(self(), :normal)
    {:noreply, state}
  end

  def handle_info({:http, socket, {:http_request, :GET, {:abs_path, path}, {1, 1}}}, state) do
    Logger.info "Request to path '#{path}'"
    :ok = :inet.setopts(socket, [packet: :httph])
    {:noreply, state}
  end

  def handle_info({:http, _socket, {:http_header, _len, header, _header_str, value}}, state) do
    Logger.info "Header #{header}: '#{value}'"
    {:noreply, state}
  end

  def handle_info({:http, socket, :http_eoh}, state) do
    Logger.info("End of request")
    :ok = :inet.setopts(socket, [packet: :http])

    data = "Hello world!"
    :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Type: text\r\nContent-Length: #{String.length(data)}\r\nServer: Rosenhoff\r\n\r\n#{data}")

    {:noreply, state}
  end

  defp get_client_name(socket) do
    {:ok, {addr, port}} = :inet.peername(socket)
    addr_str = :inet.ntoa(addr)
    "#{addr_str}:#{port}"
  end
end

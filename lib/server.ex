defmodule Server do
  require Logger
  use Task

  def start_link(port) when is_integer(port) do
    Task.start_link(__MODULE__, :run, [port])
  end

  def run(port) do
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, active: true, packet: :http, reuseaddr: true])
    Logger.info "Listening on port #{port}"
    loop_acceptor(listen_socket)
  end

  defp loop_acceptor(listen_socket) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)
    {:ok, client_pid} = DynamicSupervisor.start_child(KVS.ClientSupervisor, {HttpServer, client_socket})
    :ok = :gen_tcp.controlling_process(client_socket, client_pid) # transfer control of socket to newly started pid

    loop_acceptor(listen_socket)
  end
end

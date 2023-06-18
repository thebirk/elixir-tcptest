defmodule KVS do
  use Application

  def start(_type, _args) do
    children = [
      {HttpTestServer, Application.fetch_env!(:tcptest, :port)},
      {DynamicSupervisor, strategy: :one_for_one, name: KVS.ClientSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule HttpTestServer do
  require Logger
  use HttpServer

  def start_link(port) do
    HttpServer.start_link(__MODULE__, [port: port, dynamic_supervisor: KVS.ClientSupervisor, name: Elixir.KVS.HttpTestServer])
  end

  def handle_request(:GET, "/teapot", _headers) do
    {418, [], "<h1>Teapot!</h1>", "text"}
  end

  def handle_request(:GET, "/favicon.ico", _headers) do
    {404, [], "Not found", "text"}
  end

  def handle_request(method, path, _headers) do
    Logger.info "Request: #{method} '#{path}'"
    {200, [], "<h1>Hello, world!</h1>\n<p>Method: #{method}. Path: #{path}</p>", "text"}
  end
end

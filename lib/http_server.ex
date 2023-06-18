defmodule HttpServer do
  require Logger

  @callback handle_request(method :: (atom() | String.t()), path :: String.t(), headers :: list(%{name: String.t(), value: String.t()})) :: {status_code :: integer(), headers :: list(%{name: String.t(), value: String.t()}), body :: String.t(), content_type :: String.t()}

  @initialState %{
    socket: nil,
    version: nil,
    method: nil,
    path: nil,
    headers: []
  }

  def start_link(module, args) do
    port = Keyword.get(args, :port, 80)
    supervisor = Keyword.fetch!(args, :dynamic_supervisor)

    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, active: true, reuseaddr: true, packet: :http])
    Logger.info "Listening on port #{port}"
    pid = spawn_link(__MODULE__, :listen, [supervisor, module, listen_socket])
    if Keyword.has_key?(args, :name) do
      Process.register(pid, Keyword.fetch!(args, :name))
    end
    {:ok, pid}
  end

  def listen(supervisor, module, listen_socket) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)
    client_pid = spawn(__MODULE__, :accept, [module, client_socket, %{@initialState | socket: client_socket}])
    :gen_tcp.controlling_process(client_socket, client_pid)
    Logger.info "New connection"

    listen(supervisor, module, listen_socket)
  end

  def accept(module, socket, state) do
    new_state = receive do
      {:http, socket, {:http_request, method, {:abs_path, path}, version = {1, 1}}} ->
        state = %{state | version: version, path: path, method: method}
        :ok = :inet.setopts(socket, [packet: :httph])
        state
      {:http, _socket, {:http_header, _len, header, _header_str, value}} ->
        state = %{state | headers: [%{name: header, value: value} | state.headers]}
        state
      {:http, socket, :http_eoh} ->
        :ok = :inet.setopts(socket, [packet: :http])

        {status_code, headers, body, content_type} = module.handle_request(state.method, to_string(state.path), state.headers)

        status_line = "HTTP/1.1 #{status_code} #{status_from_code(status_code)}\r\n"
        headers = [%{name: "Content-Length", value: String.length(body)} | headers]
        headers = [%{name: "Content-Type", value: content_type} | headers]

        resp_headers = headers
          |> Enum.map(fn x -> "#{x.name}: #{x.value}\r\n" end)
          |> Enum.join()

        :gen_tcp.send(socket, status_line <> resp_headers <> "\r\n" <> body)

        %{@initialState | socket: socket}
      {:tcp_closed, _socket} ->
        Process.exit(self(), :normal)
        state
      msg ->
        IO.inspect(msg)
        state
    end

    accept(module, socket, new_state)
  end

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour HttpServer

      def child_spec(args) do
        default = %{id: __MODULE__, start: {__MODULE__, :start_link, [args]}}

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end
    end
  end

  @dialyzer { :nowarn_function, status_from_code: 1 }
  defp status_from_code(code) do
    case code do
      100 -> "Continue"
      101 -> "Switching protocols"
      102 -> "Processing"
      103 -> "Early Hints"
      200 -> "OK"
      201 -> "Created"
      202 -> "Accepted"
      203 -> "Non-Authoritative Information"
      204 -> "No Content"
      205 -> "Reset Content"
      206 -> "Partial Content"
      207 -> "Multi-Status"
      208 -> "Already Reported"
      226 -> "IM Used"
      300 -> "Multiple Choices"
      301 -> "Moved Permanently"
      302 -> "Found"
      303 -> "See Other"
      304 -> "Not Modified"
      305 -> "Use Proxy"
      306 -> "Switch Proxy"
      307 -> "Temporary Redirect"
      308 -> "Permanent Redirect"
      400 -> "Bad Request"
      401 -> "Unauthorized"
      402 -> "Payment Required"
      403 -> "Forbidden"
      404 -> "Not Found"
      405 -> "Method Not Allowed"
      406 -> "Not Acceptable"
      407 -> "Proxy Authentication Required"
      408 -> "Request Timeout"
      409 -> "Conflict"
      410 -> "Gone"
      411 -> "Length Required"
      412 -> "Precondition Failed"
      413 -> "Payload Too Large"
      414 -> "URI Too Long"
      415 -> "Unsupported Media Type"
      416 -> "Range Not Satisfiable"
      417 -> "Expectation Failed"
      418 -> "I'm a Teapot"
      421 -> "Misdirected Request"
      422 -> "Unprocessable Entity"
      423 -> "Locked"
      424 -> "Failed Dependency"
      425 -> "Too Early"
      426 -> "Upgrade Required"
      428 -> "Precondition Required"
      429 -> "Too Many Requests"
      431 -> "Request Header Fields Too Large"
      451 -> "Unavailable For Legal Reasons"
      500 -> "Internal Server Error"
      501 -> "Not Implemented"
      502 -> "Bad Gateway"
      503 -> "Service Unavailable"
      504 -> "Gateway Timeout"
      505 -> "HTTP Version Not Supported"
      506 -> "Variant Also Negotiates"
      507 -> "Insufficient Storage"
      508 -> "Loop Detected"
      510 -> "Not Extended"
      511 -> "Network Authentication Required"
      _ -> "Unknown"
    end
  end

end

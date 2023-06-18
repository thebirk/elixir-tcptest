defmodule HttpGenServer do
  require Logger
  use GenServer

  @callback handle_request(method :: (atom() | String.t()), path :: String.t(), headers :: term) :: {status_code :: integer(), headers :: term, body :: String.t(), content_type :: String.t()}

  @initialState %{
    socket: nil,
    version: nil,
    method: nil,
    path: nil,
    headers: nil
  }

  def start_link(socket, opts \\ []) do
    GenServer.start_link(__MODULE__, socket, opts)
  end

  def init(socket) do
    {:ok, %{@initialState | socket: socket}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Process.exit(self(), :normal)
    {:noreply, state}
  end

  def handle_info({:http, socket, {:http_request, method, {:abs_path, path}, version = {1, 1}}}, state) do
    state = %{state | version: version, path: path, method: method}
    :ok = :inet.setopts(socket, [packet: :httph])
    {:noreply, state}
  end

  def handle_info({:http, _socket, {:http_header, _len, header, _header_str, value}}, state) do
    state = %{state | headers: [%{name: header, value: value} | state.headers]}
    {:noreply, state}
  end

  def handle_info({:http, socket, :http_eoh}, state) do
    :ok = :inet.setopts(socket, [packet: :http])

    {status_code, headers, body, content_type} = handle_request(:http_request, {state.method, to_string(state.path), state.headers})

    status_line = "HTTP/1.1 #{status_code} #{status_from_code(status_code)}\r\n"
    headers = [%{name: "Content-Length", value: String.length(body)} | headers]
    headers = [%{name: "Content-Type", value: content_type} | headers]

    resp_headers = headers
      |> Enum.map(fn x -> "#{x.name}: #{x.value}\r\n" end)
      |> Enum.join()

    :gen_tcp.send(socket, status_line <> resp_headers <> "\r\n" <> body)

    {:noreply, %{@initialState | socket: socket}}
  end

  def handle_request(:http_request, {:GET, "/", _headers}) do
    {200, [%{name: "Server", value: "Rosenhoff"}], "<h1>Hello world!</h1>", "text"}
  end

  def handle_request(:http_request, {:GET, "/teapot", _heders}) do
    {418, [], "<h1>TEAPOT!</h1>", "text"}
  end

  def handle_request(:http_request, {_method, _path, _headers}) do
    {404, [%{name: "Server", value: "Rosenhoff"}], "Not found", "text"}
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

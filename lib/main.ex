defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  def listen() do
    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])
    main_loop(socket)
  end

  def main_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client)
    main_loop(socket)
  end

  def serve(client) do
    Task.async(fn ->
      response = read_request(client)
      write_response(client, response)
      serve(client)
    end)
  end

  defp read_request(client) do
    {:ok, raw_data} = :gen_tcp.recv(client, 0)
    [request_data | request_body] = raw_data |> String.split("\r\n\r\n", trim: true)
    [request_line | headers] = request_data |> String.split("\r\n", trim: true)
    [method, url, _version] = request_line |> String.split(" ", trim: true)
    run_request(method, url, request_body, headers)
  end

  defp write_response(client, response) do
    :gen_tcp.send(client, response)
  end

  defp run_request("GET", "/user-agent", _, headers) do
    user_agent_value =
      headers
      |> Enum.find(fn header -> String.starts_with?(header, "User-Agent") end)
      |> String.split("User-Agent: ", trim: true)
      |> hd()

    format_response(200, user_agent_value)
  end

  defp run_request("GET", "/echo/" <> echo_body, _, _) do
    format_response(200, echo_body)
  end

  defp run_request("GET", "/", _, _) do
    format_response(200, "OK")
  end

  defp run_request(_method, _url, _, _) do
    format_response(404, "Not Found")
  end

  defp format_response(200, body) do
    if String.length(body) != 0 do
      formatted_body = format_body(body)
      "HTTP/1.1 200 OK\r\n#{formatted_body}"
    else
      "HTTP/1.1 200 OK\r\n\r\n"
    end
  end

  defp format_response(404, _body) do
    "HTTP/1.1 404 Not Found\r\n\r\n"
  end

  defp format_body(body) do
    "Content-Type: text/plain\r\nContent-Length: #{String.length(body)}\r\n\r\n#{body}"
  end
end

defmodule CLI do
  def main(_args) do
    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_http_server)

    # Run forever
    Process.sleep(:infinity)
  end
end

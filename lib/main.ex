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
    # {:ok, raw_data} = :gen_tcp.recv(client, 0)
    "HTTP/1.1 200 OK\r\n\r\n"
  end

  defp write_response(client, response) do
    :gen_tcp.send(client, response)
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

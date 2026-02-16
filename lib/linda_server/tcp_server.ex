defmodule LindaServer.TCPServer do
  use GenServer

  @port 54321

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    opts = [
      :binary,
      {:packet, :line},
      {:active, false},
      {:reuseaddr, true}
    ]

    case :gen_tcp.listen(@port, opts) do
      {:ok, socket} ->
        IO.puts("Servidor Linda ouvindo na porta #{@port}")
        spawn(fn -> accept_loop(socket) end)
        {:ok, %{socket: socket}}

      {:error, reason} ->
        IO.puts("Erro ao abrir porta #{@port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  
  defp accept_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    spawn(fn -> client_loop(client) end)

    accept_loop(socket)
  end

  defp client_loop(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        response =
          data
          |> String.trim()
          |> handle_command()

        :gen_tcp.send(socket, response <> "\n")

        client_loop(socket)

      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end

  defp handle_command(cmd) do
    case String.split(cmd, " ") do
      ["WR", k, v] ->
        LindaServer.TupleSpace.wr(k, v)
        "OK"

      ["RD", k] ->
        {:ok, v} = LindaServer.TupleSpace.rd(k)
        "OK #{v}"

      ["IN", k] ->
        {:ok, v} = LindaServer.TupleSpace.in_op(k)
        "OK #{v}"

      ["EX", k_in, k_out, svc] ->
        svc_id = String.to_integer(svc)

        case LindaServer.TupleSpace.ex(k_in, k_out, svc_id) do
          :ok -> "OK"
          :no_service -> "NO-SERVICE"
        end

      _ ->
        "ERROR"
    end
  rescue
    _ -> "ERROR"
  end
end


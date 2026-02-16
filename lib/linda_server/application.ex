defmodule LindaServer.Application do
  use Application

  def start(_type, _args) do
    children = [
      LindaServer.TupleSpace,
      LindaServer.TCPServer
    ]

    opts = [strategy: :one_for_one, name: LindaServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end


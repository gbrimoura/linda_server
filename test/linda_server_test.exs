defmodule LindaServerTest do
  use ExUnit.Case
  doctest LindaServer

  test "greets the world" do
    assert LindaServer.hello() == :world
  end
end

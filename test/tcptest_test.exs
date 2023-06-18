defmodule TcptestTest do
  use ExUnit.Case
  doctest Tcptest

  test "greets the world" do
    assert Tcptest.hello() == :world
  end
end

defmodule JavaScriptTest do
  use ExUnit.Case
  doctest JavaScript

  test "greets the world" do
    assert JavaScript.hello() == :world
  end
end

defmodule JavaScript.Runtime.NodeJSTest do
  use ExUnit.Case, async: true

  alias JavaScript.Runtime.NodeJS

  setup do
    root = Path.expand("../../js", __DIR__)
    {:ok, port} = NodeJS.init(root: root)
    %{port: port}
  end

  describe "call/3" do
    test "supports calling default export", %{port: port} do
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-default", ["hello"]})
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-default", nil, ["hello"]})
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-default", [], ["hello"]})
    end

    test "supports calling named export", %{port: port} do
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-named", :echo, ["hello"]})
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-named", [:echo], ["hello"]})
    end

    test "supports calling named, nested export", %{port: port} do
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-named-nested", [:nest, :echo], ["hello"]})
    end

    test "supports arguments which can be serializable to JSON", %{port: port} do
      # number
      assert {:ok, 1024} = NodeJS.call(port, {"echo-default", [1024]})
      # string
      assert {:ok, "hello, world"} = NodeJS.call(port, {"echo-default", ["hello, world"]})
      # boolean
      assert {:ok, true} = NodeJS.call(port, {"echo-default", [true]})
      # map <-> object
      assert {:ok, %{"key" => "value"}} = NodeJS.call(port, {"echo-default", [%{key: "value"}]})
      # list <-> array
      assert {:ok, [1, 2, 3]} = NodeJS.call(port, {"echo-default", [[1, 2, 3]]})
      # nil <-> null
      assert {:ok, nil} = NodeJS.call(port, {"echo-default", [nil]})
    end

    test "supports calling async functions", %{port: port} do
      assert {:ok, "hello"} = NodeJS.call(port, {"echo-async", ["hello"]})
    end

    test "supports calling module as directory", %{port: port} do
      assert {:ok, "hello"} = NodeJS.call(port, {"subdirectory", ["hello"]})
    end

    test "supports using NPM dependencies", %{port: port} do
      {:ok, uuid} = NodeJS.call(port, {"edge-cases", :uuid, []})
      assert String.length(uuid) == 36
    end

    test "returns an error when the module doesn't exist", %{port: port} do
      assert {:error,
              %JavaScript.Runtime.Error{
                message: "Cannot find module 'missing'" <> _
              }} =
               NodeJS.call(port, {"missing", :echo, ["hello"]})
    end

    test "returns an error when the function doesn't exist", %{port: port} do
      assert {:error,
              %JavaScript.Runtime.Error{
                message: "Could not find function 'missing' in module 'echo-named'"
              }} =
               NodeJS.call(port, {"echo-named", :missing, ["hello"]})
    end

    test "return an error when the function throw an error", %{port: port} do
      assert {:error,
              %JavaScript.Runtime.Error{
                message: "oops",
                stack: "TypeError: oops\n" <> _
              }} =
               NodeJS.call(port, {"edge-cases", :throwError, []})
    end
  end

  test "writing to stdout doesn't crash the process", %{port: port} do
    assert {:ok, "hello"} = NodeJS.call(port, {"edge-cases", :writeToStdout, ["hello"]})
  end

  test "large payload doesn't crash the process", %{port: port} do
    assert {:ok, _} = NodeJS.call(port, {"echo-default", [String.duplicate("x", 65535)]})
  end
end

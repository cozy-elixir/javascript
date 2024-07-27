defmodule JavaScript.Runtime.NodeJS do
  @moduledoc """
  The runtime implementation for Node.js.

  ## References

    * [revelrylabs/elixir-nodejs](https://github.com/revelrylabs/elixir-nodejs)

  """

  @behaviour JavaScript.Runtime

  @doc """
  Initializes the Node.js runtime.

  ## Options

    * `:root` - the root path of your Node.js project.

  """
  @impl true
  def init(opts) do
    root = Keyword.fetch!(opts, :root)

    node_bin = get_node_bin()
    repl_js = get_repl_js()

    port =
      Port.open(
        {:spawn_executable, node_bin},
        [
          {:args, [repl_js]},
          {:env,
           [
             {~c"NODE_PATH", root |> get_module_search_paths() |> String.to_charlist()}
           ]},
          # options which are necessary
          :binary,
          {:packet, 4},
          :nouse_stdio,
          # options which are better to have
          :hide,
          {:parallelism, true}
        ]
      )

    {:ok, port}
  end

  defp get_node_bin do
    System.find_executable("node")
  end

  defp get_repl_js do
    Path.join([:code.priv_dir(:javascript), "runtime/node_js/repl.js"])
  end

  @doc """
  Calls an instruction in Node.js runtime.
  """
  @impl true
  def call(port, ma_mfa, opts \\ [])

  def call(port, {mod, args}, opts) do
    call(port, {mod, [], args}, opts)
  end

  def call(port, {_mod, _fun, _args} = inst, opts) do
    {timeout, opts} = Keyword.pop(opts, :timeout, 5000)
    send(port, {self(), {:command, encode_inst!(inst, opts)}})

    receive do
      {^port, {:data, result}} ->
        decode_result!(result)
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp encode_inst!({mod, fun, args}, opts) do
    :erlang.term_to_binary([
      {mod, List.wrap(fun), args},
      Map.new(opts)
    ])
  end

  defp decode_result!(result) do
    result
    |> :erlang.binary_to_term()
    |> case do
      ["ok", value] ->
        {:ok, value}

      ["error", %{"message" => message, "stack" => stack}] ->
        {:error, %JavaScript.Runtime.Error{message: message, stack: stack}}
    end
  end

  defp get_module_search_paths(path) do
    sep =
      case :os.type() do
        {:win32, _} -> ";"
        _ -> ":"
      end

    [path, Path.join(path, "node_modules")]
    |> Enum.join(sep)
  end
end

defmodule JavaScript.Runtime.NodeJS do
  @moduledoc """
  The runtime implementation for Node.js.

  ## References

    * [revelrylabs/elixir-nodejs](https://github.com/revelrylabs/elixir-nodejs)

  """

  @behaviour JavaScript.Runtime

  # The protocol refers to the format in which information is transmitted
  # between Elixir and Node.js.
  # In order to make sure that no one can interfere with the protocol between
  # them, every lines written by Node.js are prefixed by following string.
  @protocol_prefix "__elixir_javascript_runtime_nodejs__"

  # Port can NOT handle more than this
  @chunk_size 65_536

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
             # TODO: rename it to MODULE_SEARCH_PATHS
             {~c"NODE_PATH", root |> get_module_search_paths() |> String.to_charlist()},
             {~c"PROTOCOL_PREFIX", @protocol_prefix |> String.to_charlist()},
             {~c"WRITE_CHUNK_SIZE", @chunk_size |> to_string() |> String.to_charlist()}
           ]},
          :binary,
          {:line, @chunk_size},
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
    call(port, {mod, nil, args}, opts)
  end

  def call(port, {_mod, _fun, _args} = instruction, opts) do
    send(port, {self(), {:command, encode_instruction!(instruction, opts)}})

    with {:ok, result} <- receive_result(port, 5000) do
      decode_result!(result)
    end
  end

  defp encode_instruction!({mod, fun, args}, opts) do
    Jason.encode!([
      Tuple.to_list({mod, List.wrap(fun), args}),
      Map.new(opts)
    ]) <> "\n"
  end

  defp receive_result(port, timeout), do: receive_result(port, "", timeout)

  defp receive_result(port, data, timeout) do
    receive do
      {^port, {:data, {:noeol, line}}} ->
        data = data <> line
        receive_result(port, data, timeout)

      {^port, {:data, {:eol, line}}} ->
        data = data <> line

        case data do
          @protocol_prefix <> result ->
            {:ok, result}

          _ ->
            # If the format of the data does not comply with the protocol
            # requirements, then attempt to retrieve it again.
            receive_result(port, timeout)
        end
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp decode_result!(result) do
    result
    |> Jason.decode!()
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

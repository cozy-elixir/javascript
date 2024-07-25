defmodule JavaScript.Runtime do
  @moduledoc """
  The namespace for JavaScript runtimes.

  Nowadays, there are several mainstream JavaScript runtimes:

    * [Node.js](https://nodejs.org)
    * [Bun](https://bun.sh)
    * ...

  """

  @type opts :: keyword()

  @doc """
  Initializes the runtime.
  """
  @callback init(opts()) :: {:ok, port()} | {:error, any()}

  @type mod :: atom() | binary()
  @type fun :: atom() | binary() | [atom() | binary()]
  @type args :: [any()]

  @doc """
  Calls an instruction.

  An instruction is a tuple in format of `{mod, args}` or `{mod, fun, args}`.
  """
  @callback call(port(), {mod(), args()} | {mod(), fun(), args()}, opts()) ::
              {:ok, any()} | {:error, JavaScript.Runtime.Error.t()}
end

defmodule JavaScript.Runtime.Error do
  defexception [:message, :stack]

  @type t :: %__MODULE__{}
end

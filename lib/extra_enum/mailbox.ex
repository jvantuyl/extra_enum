defmodule ExtraEnum.Mailbox do
  @moduledoc """
  Enumerates against the mailbox by matching.

  Can match a single pattern or multiple patterns.  Arbitrary code can be
  executed when using the multiple pattern syntax, giving feature parity with
  `Kernel.SpecialForms.receive/1`.

  Stops enumerating when the end of the mailbox is reached.  Can be asked to
  delay momentarily to allow late messages to filter in.

  ## Examples

  ### Single Pattern Match

      iex> require ExtraEnum.Mailbox, as: Mailbox
      iex> send(self(), {:message, :test1})
      {:message, :test1}
      iex> send(self(), {:message, :test2})
      {:message, :test2}
      iex> Mailbox.match({:message, _}) |> Enum.to_list()
      [{:message, :test1}, {:message, :test2}]

  ### Multiple Pattern Match

      iex> require ExtraEnum.Mailbox, as: Mailbox
      iex> send(self(), {:message, :test1})
      {:message, :test1}
      iex> send(self(), {:message, :test2})
      {:message, :test2}
      iex> Mailbox.match do
      ...>   {:message, :test1} -> 1
      ...>   {:message, :test2} -> 2
      ...> end |> Enum.to_list()
      [1, 2]
  """

  # === boiler plate ===

  # Struct holds a dynamically built receiver function.  Must be dynamically
  # built to capture environment at call site in its closure.
  defstruct [:receiver]

  # === Macros ===

  @doc """
  Create an enumerable that will match a given pattern in the process mailbox.

  Accepts as parameters:
  * a single pattern as the first argument
  * multiple patterns and result values as a `do` block (like
    `Kernel.SpecialForms.case/2`)
  * a keyword list of options

  It's not allowed to use the single and multiple pattern syntax at the same
  time.

  ## Options:
    * `delay` - waits a given number of milliseconds before ending enumeration
      to allow late messages to trickle in.

  """
  defmacro match(arg1, arg2 \\ nil) do
    # Arguments move around weirdly due to quirks in default argument handling.
    # This seemed to be the easiest way to sort it out.
    case {arg1, arg2} do
      {[do: multi_pattern], nil} ->
        # do block, no opts
        build_match_many(multi_pattern, [])

      {opts, [do: multi_pattern]} when is_list(opts) ->
        # do block, opts
        build_match_many(multi_pattern, opts)

      {single_pattern, nil} ->
        # simple match, no opts
        build_match_single(single_pattern, [])

      {single_pattern, opts} when is_list(opts) ->
        # simple match, opts
        build_match_single(single_pattern, opts)
    end
  end

  @doc """
  Like `match/2`, but only accepts the single match syntax.
  """
  defmacro match_single(single_pattern, opts \\ []) when is_list(opts) do
    build_match_single(single_pattern, opts)
  end

  @doc """
  Like `match/2`, but only accepts the multiple match syntax.
  """
  defmacro match_many(opts \\ [], do: multi_pattern) when is_list(opts) do
    build_match_many(multi_pattern, opts)
  end

  # === helper functions ===

  defp build_match_single(single_pattern, opts) when is_list(opts) do
    delay = Keyword.get(opts, :delay, 0)

    quote location: :keep do
      %unquote(__MODULE__){
        receiver: fn timeout_ref ->
          receive do
            unquote(single_pattern) = msg ->
              msg
          after
            unquote(delay) ->
              timeout_ref
          end
        end
      }
    end
  end

  defp build_match_many(multi_pattern, opts) when is_list(opts) do
    delay = Keyword.get(opts, :delay, 0)

    quote location: :keep do
      %unquote(__MODULE__){
        receiver: fn timeout_ref ->
          receive do
            unquote(multi_pattern)
          after
            unquote(delay) ->
              timeout_ref
          end
        end
      }
    end
  end

  # === protocol implementation ===

  defimpl Enumerable do
    alias ExtraEnum.Mailbox

    def reduce(%Mailbox{} = _mailbox, {:halt, acc}, fun) when is_function(fun), do: {:halted, acc}

    def reduce(%Mailbox{} = mailbox, {:suspend, acc}, fun) when is_function(fun),
      do: {:suspended, acc, &reduce(mailbox, &1, fun)}

    def reduce(%Mailbox{} = mailbox, {:cont, acc}, fun) when is_function(fun) do
      timeout_ref = make_ref()

      case mailbox.receiver.(timeout_ref) do
        ^timeout_ref ->
          {:done, acc}

        msg ->
          reduce(mailbox, fun.(msg, acc), fun)
      end
    end

    def slice(%Mailbox{}), do: {:error, __MODULE__}
    def count(%Mailbox{}), do: {:error, __MODULE__}
    def member?(%Mailbox{}, _), do: {:error, __MODULE__}
  end
end

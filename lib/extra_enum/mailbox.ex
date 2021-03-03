defmodule ExtraEnum.Mailbox do
  @moduledoc """
  Enumerates against the mailbox by matching.

  # Examples

  ## Single Pattern Match

      iex> require ExtraEnum.Mailbox, as: Mailbox
      iex> send(self(), {:message, :test1})
      {:message, :test1}
      iex> send(self(), {:message, :test2})
      {:message, :test2}
      iex> Mailbox.match({:message, _}) |> Enum.to_list()
      [{:message, :test1}, {:message, :test2}]

  ## Multiple Pattern Match

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
  defstruct [:receiver]

  @doc """
  Create an enumerable that will match a given pattern in the process mailbox.

  Example:

  """
  defmacro match(arg1, arg2 \\ nil) do
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

  defmacro match_single(single_pattern, opts \\ []) when is_list(opts) do
    build_match_single(single_pattern, opts)
  end

  defmacro match_many(opts \\ [], do: multi_pattern) when is_list(opts) do
    build_match_many(multi_pattern, opts)
  end

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

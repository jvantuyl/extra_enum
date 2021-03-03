defmodule ExtraEnumMailboxTest do
  use ExUnit.Case, async: true
  doctest ExtraEnum.Mailbox

  test "mailbox matching enum" do
    import ExtraEnum.Mailbox

    send(self(), :a)
    send(self(), :b)
    send(self(), :b)
    send(self(), :c)
    send(self(), :d)

    recv_ac =
      match do
        :a -> 1
        :c -> 2
      end

    assert Enum.to_list(recv_ac) == [1, 2]

    recv_b = match(:b)

    assert Enum.to_list(recv_b) == [:b, :b]

    assert Process.info(self(), :messages) == {:messages, [:d]}
  end
end

defmodule SaltpackTest do
  use ExUnit.Case
  doctest Saltpack

  test "encryption cycle" do
    {ask, apk} = Saltpack.new_key_pair
    {bsk, bpk} = Saltpack.new_key_pair

    short_message = :crypto.rand_bytes(32)
    long_message  = :crypto.rand_bytes(8192)

    assert Saltpack.encrypt_message(short_message, [bpk], ask) |> Saltpack.open_message(bsk) == short_message
    assert Saltpack.encrypt_message(long_message, [apk], bsk) |> Saltpack.open_message(ask)  == long_message
  end

  test "armor cycle" do
    {ask, _apk}    = Saltpack.new_key_pair # Not actually needed, but showing API obliviousness
    short_message = :crypto.rand_bytes(32)
    long_message  = :crypto.rand_bytes(8192)

    assert Saltpack.armor_message(short_message) |> Saltpack.open_message(ask) == short_message
    assert Saltpack.armor_message(long_message) |> Saltpack.open_message(ask)  == long_message

  end

end

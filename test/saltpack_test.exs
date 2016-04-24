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

  test "signing cycles" do
    {ask, apk} = Saltpack.new_key_pair(:sign)

    short_message = :crypto.rand_bytes(32)
    long_message  = :crypto.rand_bytes(8192)

    assert Saltpack.sign_message(short_message, ask) |> Saltpack.open_message == short_message
    assert Saltpack.sign_message(long_message, ask) |> Saltpack.open_message  == long_message

    assert Saltpack.sign_message(short_message, ask, apk, :detached) |> Saltpack.open_message(nil, short_message) == apk

  end

  test "armor cycle" do
    {ask, _apk}    = Saltpack.new_key_pair # Not actually needed, but showing API obliviousness
    short_message = :crypto.rand_bytes(32)
    long_message  = :crypto.rand_bytes(8192)

    assert Saltpack.armor_message(short_message) |> Saltpack.open_message(ask) == short_message
    assert Saltpack.armor_message(long_message) |> Saltpack.open_message(ask)  == long_message

  end

end

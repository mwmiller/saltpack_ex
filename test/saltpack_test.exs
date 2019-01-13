defmodule SaltpackTest do
  use ExUnit.Case
  doctest Saltpack

  test "encryption cycle" do
    {ask, apk} = Saltpack.new_key_pair()
    {bsk, bpk} = Saltpack.new_key_pair()

    short_message = :crypto.strong_rand_bytes(32)
    long_message = :crypto.strong_rand_bytes(8192)

    assert short_message |> Saltpack.encrypt_message([bpk], ask) |> Saltpack.open_message(bsk) ==
             short_message

    assert long_message |> Saltpack.encrypt_message([apk], bsk) |> Saltpack.open_message(ask) ==
             long_message
  end

  test "signing cycles" do
    {ask, apk} = Saltpack.new_key_pair(:sign)

    short_message = :crypto.strong_rand_bytes(32)
    long_message = :crypto.strong_rand_bytes(8192)

    assert short_message |> Saltpack.sign_message(ask) |> Saltpack.open_message() == short_message
    assert long_message |> Saltpack.sign_message(ask) |> Saltpack.open_message() == long_message

    assert short_message
           |> Saltpack.sign_message(ask, apk, :detached)
           |> Saltpack.open_message(nil, short_message) == apk
  end

  test "armor cycle" do
    # Not actually needed, but showing API obliviousness
    {ask, _apk} = Saltpack.new_key_pair()
    short_message = :crypto.strong_rand_bytes(32)
    long_message = :crypto.strong_rand_bytes(8192)

    assert short_message |> Saltpack.armor_message() |> Saltpack.open_message(ask) ==
             short_message

    assert long_message |> Saltpack.armor_message() |> Saltpack.open_message(ask) == long_message
  end
end

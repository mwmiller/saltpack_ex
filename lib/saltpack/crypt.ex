defmodule Saltpack.Crypt do
  @moduledoc false

  @header_sbox_nonce "saltpack_sender_key_sbox"
  @header_box_nonce "saltpack_payload_key_box"
  @nil_key <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0>>
  @format "saltpack"
  @version [1, 0]
  @mode 0

  defp pack_header(recipients, our_private, our_public) do
    {epriv, epub} = Kcl.generate_key_pair()
    payload_key = :crypto.strong_rand_bytes(32)

    hbody =
      IO.iodata_to_binary(
        Msgpax.pack!([
          @format,
          @version,
          @mode,
          # ephemeral public key
          Msgpax.Bin.new(epub),
          Msgpax.Bin.new(Kcl.secretbox(our_public, @header_sbox_nonce, payload_key)),
          recipients
          |> recipient_boxes(@header_box_nonce, payload_key, epriv, [])
          |> Enum.map(fn {k, v} -> [k |> Msgpax.Bin.new(), v |> Msgpax.Bin.new()] end)
        ])
      )

    hhash = :crypto.hash(:sha512, hbody)

    {hbody |> Msgpax.Bin.new() |> Msgpax.pack!() |> IO.iodata_to_binary(),
     recipients
     |> recipient_boxes(first_bytes(hhash, 24), @nil_key, our_private, [])
     |> Enum.map(fn {_k, v} -> v |> last_bytes(32) end), payload_key, hhash}
  end

  def create_message(payload, recipients, private, public \\ nil)

  def create_message(payload, recipients, private, public) when public == nil,
    do: create_message(payload, recipients, private, Kcl.derive_public_key(private, :encrypt))

  def create_message(payload, recipients, private, public) do
    {header, macs, payload_key, header_hash} = pack_header(recipients, private, public)
    header <> pack_payload(payload, macs, payload_key, header_hash, 0, [])
  end

  defp nonce(n), do: "saltpack_ploadsb" <> (n |> :binary.encode_unsigned() |> pad(8))
  defp pad(s, n) when byte_size(s) == n, do: s
  defp pad(s, n) when byte_size(s) < n, do: pad(<<0>> <> s, n)

  defp pack_payload(
         <<m::binary-size(1024), rest::binary>>,
         recipients,
         payload_key,
         header_hash,
         nonce_count,
         acc
       ) do
    pack_payload(rest, recipients, payload_key, header_hash, nonce_count + 1, [
      code_payload(m, recipients, payload_key, nonce(nonce_count), header_hash) | acc
    ])
  end

  defp pack_payload(final, recipients, payload_key, header_hash, nonce_count, acc) do
    (acc |> Enum.reverse() |> Enum.join()) <>
      code_payload(final, recipients, payload_key, nonce(nonce_count), header_hash) <>
      code_payload("", recipients, payload_key, nonce(nonce_count + 1), header_hash)
  end

  defp code_payload(payload, recipients, payload_key, nonce, header_hash) do
    payload_secretbox = Kcl.secretbox(payload, nonce, payload_key)

    [
      authenticators(
        recipients,
        :crypto.hash(:sha512, Enum.join([header_hash, nonce, payload_secretbox])),
        []
      ),
      payload_secretbox |> Msgpax.Bin.new()
    ]
    |> Msgpax.pack!()
    |> IO.iodata_to_binary()
  end

  defp authenticators([], _hash, acc), do: acc |> Enum.reverse()

  defp authenticators([r | rest], hash, acc),
    do:
      authenticators(rest, hash, [
        Msgpax.Bin.new(:crypto.macN(:hmac, :sha512, r, hash, 32)) | acc
      ])

  defp recipient_boxes([], _nonce, _payload, _priv, acc), do: acc |> Enum.reverse()

  defp recipient_boxes([r | rest], nonce, payload, priv, acc) do
    rkey = if r, do: r, else: @nil_key

    recipient_boxes(rest, nonce, payload, priv, [
      {r, stateless_box(payload, nonce, priv, rkey)} | acc
    ])
  end

  def open_message(message, our_private) do
    message
    |> header_verify(our_private)
    |> payloads_open(0, [])
  end

  defp payloads_open(_finished_payloads, _n, ["" | acc]), do: acc |> Enum.reverse() |> Enum.join()

  defp payloads_open({payloads, index, payload_key, hhash, mac}, nonce_count, acc) do
    nonce = nonce(nonce_count)
    {payload, rest} = Msgpax.unpack_slice!(payloads)
    {tauth, sb} = {payload |> Enum.at(0) |> Enum.at(index), Enum.at(payload, 1)}

    oauth =
      :crypto.macN(:hmac, :sha512, mac, :crypto.hash(:sha512, Enum.join([hhash, nonce, sb])), 32)

    if not Equivalex.equal?(oauth, tauth), do: decrypt_error()

    payloads_open({rest, index, payload_key, hhash, mac}, nonce_count + 1, [
      Kcl.secretunbox(sb, nonce, payload_key) | acc
    ])
  end

  defp header_verify(packet, priv) do
    {contents, rest} = Msgpax.unpack_slice!(packet)
    hhash = :crypto.hash(:sha512, contents)
    [format, version, mode, epub, secret_box, recipients] = Msgpax.unpack!(contents)
    # Should be smarter here regarding version, eventually
    if format != @format or version != @version or mode != @mode, do: decrypt_error()
    {index, payload_key} = payload_info(recipients, priv, epub)

    {rest, index, payload_key, hhash,
     @nil_key
     |> stateless_box(
       first_bytes(hhash, 24),
       priv,
       Kcl.secretunbox(secret_box, @header_sbox_nonce, payload_key)
     )
     |> last_bytes(32)}
  end

  defp last_bytes(s, n) do
    len = byte_size(s)
    :binary.part(s, len - n, n)
  end

  defp first_bytes(s, n), do: :binary.part(s, 0, n)

  defp payload_info(recipients, priv, tpub) do
    {opriv, opub} = if priv, do: {priv, Kcl.derive_public_key(priv)}, else: {@nil_key, @nil_key}
    index = Enum.find_index(recipients, fn [k, _] -> k == opub end)

    {index,
     recipients |> Enum.at(index) |> Enum.at(1) |> stateless_unbox(@header_box_nonce, opriv, tpub)}
  end

  defp stateless_unbox(message, nonce, private, public),
    do: message |> Kcl.unbox(nonce, private, public) |> drop_state

  defp stateless_box(message, nonce, private, public),
    do: message |> Kcl.box(nonce, private, public) |> drop_state

  defp drop_state(v) do
    {m, _state} = v
    m
  end

  defp decrypt_error, do: raise("Improper or incomplete message.")
end

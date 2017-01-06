defmodule Saltpack.Sign do
  @moduledoc false

  @format "saltpack"
  @version [1,0]

  defp mode_constant(1), do: "saltpack attached signature\0"
  defp mode_constant(2), do: "saltpack detached signature\0"

  defp pack_header(our_public, mode) when mode == 1 or mode == 2 do
    nonce = :crypto.strong_rand_bytes(32)
    hbody = [ @format,  # format
              @version, # version
              mode,     # mode:  1 (attached) or 2 (detached)
              our_public |> Msgpax.Bin.new,
              nonce |> Msgpax.Bin.new,
            ] |> Msgpax.pack! |> IO.iodata_to_binary
    hhash = :crypto.hash(:sha512,hbody)
    {hbody |> Msgpax.Bin.new |> Msgpax.pack! |> IO.iodata_to_binary, hhash}
  end

  def create_message(payload, private, mode, nil), do: create_message(payload, private, mode, Kcl.derive_public_key(private, :sign))
  def create_message(payload, private, 2, public) do
    {header, header_hash} = pack_header(public, 2)
    header<>detached_signature(payload, header_hash, private,public)
  end
  def create_message(payload, private, 1, public) do
    {header, header_hash} = pack_header(public, 1)
    header<>pack_payload(payload, header_hash, private, public, 0, [])
  end

  defp detached_signature(text, hash, private, public) do
    mode_constant(2)<>:crypto.hash(:sha512, hash<>text)
      |> Kcl.sign(private,public)
      |> Msgpax.Bin.new
      |> Msgpax.pack!
      |> IO.iodata_to_binary
  end

  defp nonce(n), do: n |> :binary.encode_unsigned |> pad(8)
  defp pad(s,n) when byte_size(s) == n, do: s
  defp pad(s,n) when byte_size(s) <  n, do: pad(<<0>><>s, n)

  defp pack_payload(<<m::binary-size(1024), rest::binary>>, header_hash, private, public, nonce_count, acc) do
    pack_payload(rest, header_hash, private, public, nonce_count+1, [code_payload(m, header_hash, private, public, nonce(nonce_count)) | acc])
  end
  defp pack_payload(final, header_hash, private, public, nonce_count, acc) do
    (acc |> Enum.reverse |> Enum.join)
      <>code_payload(final, header_hash, private, public, nonce(nonce_count))
      <>code_payload("", header_hash, private, public, nonce(nonce_count+1))
  end

  defp code_payload(payload, header_hash, private, public, nonce) do
    payload_hash = :crypto.hash(:sha512, header_hash<>nonce<>payload)
    [Kcl.sign(mode_constant(1)<>payload_hash, private, public) |> Msgpax.Bin.new, payload |> Msgpax.Bin.new]
      |> Msgpax.pack!
      |> IO.iodata_to_binary
  end

  def open_message(message, nil) do
    message
      |> header_verify(1)
      |> payloads_open(0,[])
  end
  def open_message(message, plaintext) do
    message
      |> header_verify(2)
      |> verify_msg_match(plaintext)
  end

  defp verify_msg_match({signature, hhash, opub}, text) do
    if Kcl.valid_signature?(signature |> Msgpax.unpack!, mode_constant(2)<>:crypto.hash(:sha512, hhash<>text), opub), do: opub, else: sign_error()
  end

  defp payloads_open(_finished_payloads, _n, [""|acc]), do: acc |> Enum.reverse |> Enum.join
  defp payloads_open({payloads, hhash, pub}, nonce_count, acc) do
    nonce = nonce(nonce_count)
    {[tsig, data], rest} = Msgpax.unpack_slice!(payloads)
    if not Kcl.valid_signature?(tsig, mode_constant(1)<>:crypto.hash(:sha512, hhash<>nonce<>data), pub), do: sign_error()
    payloads_open({rest, hhash, pub}, nonce_count+1, [data | acc])
  end

  defp header_verify(packet, emode)  do
    {contents, rest} = Msgpax.unpack_slice!(packet)
    hhash = :crypto.hash(:sha512,contents)
    [format, version, mode, opub, _nonce] = Msgpax.unpack!(contents)
    if format != @format or version != @version or mode != emode, do: sign_error()
    {rest, hhash, opub}
  end

  defp sign_error, do: raise("Improper or incomplete message.")

end

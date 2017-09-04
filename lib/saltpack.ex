defmodule Saltpack do
  @moduledoc """
  saltpack implementation

  https://saltpack.org/

  Handling complete, ASCII-armored messages at rest.
  """

  @typedoc """
  a public or private key
  """
  @type key :: binary

  @typedoc """
  desired key variety
  """
  @type key_variety :: :encrypt | :sign

  @typedoc """
  signature mode
  """
  @type signature_mode :: :attached | :detached


  @doc """
  generate a new `{private, public}` key pair
  """
  @spec new_key_pair(key_variety) :: {key, key}
  def new_key_pair(kv \\ :encrypt), do: Kcl.generate_key_pair(kv)

  @doc """
  encrypt a new message

  `recipients` should contain a list of all recipient public keys.
  An entry may be `nil` for anonymous recipients.
  """
  @spec encrypt_message(binary, [key], key, key, Saltpack.Armor.formatting_options) :: binary
  def encrypt_message(message, recipients, private, public \\ nil, opts \\ []) do
    message
       |> Saltpack.Crypt.create_message(recipients, private, public)
       |> Saltpack.Armor.armor_message("ENCRYPTED MESSAGE", opts)
  end

  @doc """
  sign a new message

  This is presently considerably slower than encrypting a same-sized message and
  has slightly different calling semantics. Where possible, `encrypt_message/5` should
  be preferred.
  """
  @spec sign_message(binary, key, key, signature_mode, Saltpack.Armor.formatting_options) :: binary
  def sign_message(message, private, public \\ nil, mode \\ :attached, opts \\ [])
  def sign_message(message, private, public, :attached, opts) do
    message
       |> Saltpack.Sign.create_message(private, 1, public)
       |> Saltpack.Armor.armor_message("SIGNED MESSAGE", opts)
  end
  def sign_message(message, private, public, :detached, opts) do
    message
       |> Saltpack.Sign.create_message(private, 2, public)
       |> Saltpack.Armor.armor_message("DETACHED SIGNATURE", opts)
  end

  @doc """
  armor a new message
  """
  @spec armor_message(binary, Saltpack.Armor.formatting_options) :: binary
  def armor_message(message, opts \\ []), do: message |> Saltpack.Armor.armor_message("MESSAGE", opts)

  @doc """
  open a saltpack message

  This may fail in spectacular ways with messages which are not properly
  formatted for the supplied key.

  Opening a detached signature with `plaintext` will return the signing public key.
  All other forms return the decoded contents upon validation.
  """
  @spec open_message(binary, key, binary) :: binary
  def open_message(message, key \\ nil, plaintext \\ nil) do
    case message |> Saltpack.Armor.dearmor_message do
        {"ENCRYPTEDMESSAGE", msg}  -> Saltpack.Crypt.open_message(msg, key)
        {"SIGNEDMESSAGE", msg}     -> Saltpack.Sign.open_message(msg, nil)
        {"DETACHEDSIGNATURE", msg} -> Saltpack.Sign.open_message(msg, plaintext)
        {"MESSAGE", msg}           -> msg
        _                          -> raise("No properly formatted message found.")
    end
  end

end

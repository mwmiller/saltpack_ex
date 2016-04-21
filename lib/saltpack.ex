defmodule Saltpack do
  @moduledoc """
  saltpack implementation

  https://saltpack.org/

  This library presently only handles complete, ASCII-armored messages at rest.
  Planned future support for streaming may entail a complete reconsideration of
  the API.
  """

  @typedoc """
  a public or private key
  """
  @type key :: <<_ :: 32 * 8>>

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

  Any supplied `app` name will appear in the message ASCII armoring.
  """
  @spec encrypt_message(binary, [key], key, String.t, key) :: binary
  def encrypt_message(message, recipients, private, app \\ "", public \\ nil) do
     Saltpack.Crypt.create_message(message, recipients, private, public)
       |> Saltpack.Armor.armor_message("ENCRYPTED MESSAGE", app)
  end

  @doc """
  sign a new message

  This is presently considerably slower than encrypting a same-sized message and
  has slightly different calling semantics. Where possible, `encrypt_message/4` should
  be preferred.
  """
  @spec sign_message(binary, key, String.t, signature_mode, key) :: binary
  def sign_message(message, private, app \\ "", mode \\ :attached, public \\ nil)
  def sign_message(message, private, app, :attached, public) do
     Saltpack.Sign.create_message(message, private, 1, public)
       |> Saltpack.Armor.armor_message("SIGNED MESSAGE", app)
  end
  def sign_message(message, private, app, :detached, public) do
     Saltpack.Sign.create_message(message, private, 2, public)
       |> Saltpack.Armor.armor_message("DETACHED SIGNATURE", app)
  end

  @doc """
  armor a new message

  Any supplied `app` name will appear in the message ASCII armoring.
  """
  @spec armor_message(binary, String.t) :: binary
  def armor_message(message, app \\ ""), do: message |> Saltpack.Armor.armor_message("MESSAGE", app)

  @doc """
  open a saltpack message

  This may fail in spectacular ways with messages which are not properly
  formatted for the supplied key.

  Opening a detached signature with plaintext will return the signing public key.
  All other versions return the decoded contents upon validation.
  """
  @spec open_message(binary, key, binary) :: binary
  def open_message(message, key \\ nil, plaintext \\ nil) do
    case message |> Saltpack.Armor.dearmor_message do
        {"ENCRYPTEDMESSAGE", msg}  -> Saltpack.Crypt.open_message(msg, key)
        {"SIGNEDMESSAGE", msg}     -> Saltpack.Sign.open_message(msg, nil)
        {"DETACHEDSIGNATURE", msg} -> Saltpack.Sign.open_message(msg, plaintext)
        {"MESSAGE", msg}           -> msg
        _                          -> :noop
    end
  end

end

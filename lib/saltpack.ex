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

  @doc """
  generate a new `{private, public}` key pair
  """
  @spec new_key_pair() :: {key, key}
  def new_key_pair, do: Kcl.generate_key_pair

  @doc """
  encrypt a new message

  `recipients` should contain a list of all recipient public keys.
  An entry may be `nil` for anonymous recipients.

  Any supplied `app` name will appear in the message ASCII armoring.
  """
  @spec encrypt_message(binary, [key], key, String.t) :: binary
  def encrypt_message(message, recipients, private, app \\ ""), do: Saltpack.Crypt.create_message(message, recipients, private) |> Saltpack.Armor.armor_message("ENCRYPTED MESSAGE", app)

  @doc """
  armor a new message

  Any supplied `app` name will appear in the message ASCII armoring.
  """
  @spec armor_message(binary, String.t) :: binary
  def armor_message(message, app \\ ""), do: message |> Saltpack.Armor.armor_message("MESSAGE", app)

  @doc """
  open a saltpack message

  This may fail in spectacular ways with messages which are not properly
  formatted for the supplied private key.
  """
  @spec open_message(binary, key) :: binary
  def open_message(message, private \\ nil) do
    case message |> Saltpack.Armor.dearmor_message do
        {"ENCRYPTEDMESSAGE", msg} -> Saltpack.Crypt.open_message(msg, private)
        {"MESSAGE", msg}          -> msg
        _                         -> :noop
    end
  end

end

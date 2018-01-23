defmodule Saltpack.Armor do
    @moduledoc """
    Armoring
    """

    @armorer BaseX.prepare_module("Base62Armor", "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 32)

    @typedoc """
    A keyword list with formatting options

    - `app`: the application name (default: "")
    - `chars_per_word`: grouping word-size (default: 18)
    - `words_per_line`: grouping line-size (default: 4)

    The start and end framing are always presented on separate lines.

    ```
    72 (4 words of 18 characters)
    +3 (inter-word spaces)
    +1 (end-of-message indicator: `.`)
    ==
    76 (default maximum line-length)
    ```
    """
    @type formatting_options :: [app: String.t, chars_per_word: pos_integer, words_per_line: pos_integer]

    @spec parse_options(formatting_options) :: {String.t, pos_integer, pos_integer}
    defp parse_options(options) do
      {Keyword.get(options, :app, ""),
       Keyword.get(options, :chars_per_word, 18),
       Keyword.get(options, :words_per_line, 4),
      }
    end

    @doc false
    def armor_message(m, t, o \\ []) do
      {a, cpw, wpl} = parse_options(o)
      {h, f} = head_foot(t, a)
      Enum.join([h, m |> armor_raw |> format_payload({cpw, wpl}), f], ".\n") <> "."
    end

    defp head_foot(t, a) do
      app_part = if a == "", do: "", else: a <> " "
      shared = app_part <> "SALTPACK " <> t
      {"BEGIN " <> shared, "END " <> shared}
    end

    @doc false
    def armor_raw(s), do: s |> @armorer.encode

    @doc false
    def dearmor_message(m) do
     case m |> normalize_message |> String.split(".") do
        [h, p, f, _] -> {framed_message_type(h, f), dearmor_raw(p)}
        _            -> dearmor_error()
     end
    end

    defp dearmor_error, do: raise("Invalid or incomplete message.")

    defp normalize_message(m), do: Regex.replace(~r/[>\s]+/, m, "")
    defp framed_message_type(h, f) do
      {t, pf} = case Regex.named_captures(~r/^BEGIN(?<app>[a-zA-Z0-9]+)?SALTPACK(?<type>ENCRYPTEDMESSAGE|SIGNEDMESSAGE|DETACHEDSIGNATURE|MESSAGE)$/, h) do
                  %{"app" => app, "type" => type} -> {type, "END" <> app <> "SALTPACK" <> type}
                  %{"type" => type}               -> {type, "ENDSALTPACK" <> type}
                  _                               -> {nil, nil}
                end
      if f == pf, do: t, else: dearmor_error()
    end

    @doc false
    def dearmor_raw(s), do: s |> @armorer.decode

    defp format_payload(s, {cpw, wpl}), do: s |> set_words(cpw, []) |> set_lines(wpl, [])

    defp set_words(chars, cpw, acc) when byte_size(chars) <= cpw, do: [chars|acc] |> Enum.reverse
    defp set_words(chars, cpw, acc) when byte_size(chars) >  cpw do
      {this, rest} = {:binary.part(chars, 0, cpw), :binary.part(chars, cpw, byte_size(chars) - cpw)}
      set_words(rest, cpw, [this|acc])
    end

    defp set_lines([], _wpl, acc), do: acc |> Enum.reverse |> Enum.join("\n")
    defp set_lines(words, wpl, acc) do
      {words, rest} = grab_words({}, wpl, words)
      set_lines(rest, wpl, [words |> Tuple.to_list |> Enum.join(" ")|acc])
    end

    defp grab_words(words, _count, []),  do: {words, []}
    defp grab_words(words, count, [h|t]) when tuple_size(words) <  count, do: grab_words(Tuple.append(words, h), count, t)
    defp grab_words(words, count, left)  when tuple_size(words) == count, do: {words, left}

end

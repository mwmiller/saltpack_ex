defmodule Saltpack.Armor do
    @moduledoc false

    @armorer BaseX.prepare_module("Base62Armor", "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 32)

    def armor_message(m,t,a \\ "") do
      {h,f} = head_foot(t,a)
      Enum.join([h,m |> armor_raw |> format_payload,f], ".\n")<>"."
    end

    defp head_foot(t,a) do
      app_part = if a == "", do: "", else: a<>" "
      shared = app_part<>"SALTPACK "<>t
      {"BEGIN "<>shared, "END "<>shared}
    end

    def armor_raw(s), do: s |> @armorer.encode

    def dearmor_message(m) do
     case m |> normalize_message |> String.split(".") do
        [h,p,f,_] -> {framed_message_type(h,f), dearmor_raw(p)}
        _         -> dearmor_error
     end
    end

    defp dearmor_error, do: raise("Invalid or incomplete message.")

    defp normalize_message(m), do: Regex.replace(~r/[>\s]+/, m, "")
    defp framed_message_type(h,f) do
      {t, pf} = case Regex.named_captures(~r/^BEGIN(?<app>[a-zA-Z0-9]+)?SALTPACK(?<type>ENCRYPTEDMESSAGE|SIGNEDMESSAGE|DETACHEDSIGNATURE|MESSAGE)$/, h) do
                  %{"app" => app, "type" => type} -> {type, "END"<>app<>"SALTPACK"<>type}
                  %{"type" => type}               -> {type, "ENDSALTPACK"<>type}
                  _                               -> {nil, nil}
                end
      if f == pf, do: t, else: dearmor_error
    end

    def dearmor_raw(s), do: s |> @armorer.decode

    defp format_payload(s), do: s |> set_words([]) |> set_lines([])

    defp set_words(<<>>, acc), do: acc |> Enum.reverse
    defp set_words(<<word::binary-size(18), rest::binary>>, acc), do: set_words(rest, [word|acc])
    defp set_words(short, acc), do: set_words(<<>>, [short|acc])

    defp set_lines([], acc), do: acc |> Enum.reverse |> Enum.join("\n")
    defp set_lines([a,b,c,d|rest], acc), do: set_lines(rest, [Enum.join([a,b,c,d], " ")|acc])
    defp set_lines(short, acc), do: set_lines([], [Enum.join(short, " ")|acc])

end

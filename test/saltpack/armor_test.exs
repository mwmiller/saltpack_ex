defmodule SaltpackArmorTest do
  use ExUnit.Case
  import Saltpack.Armor
  doctest Saltpack.Armor

  test "raw" do
    assert armor_raw("short") == "8j34xXQ"
    assert dearmor_raw("8j34xXQ") == "short"

    assert armor_raw("this one is much much longer than the other one") == "RbRLaEY20EoX5Js7sKUuYONmE5bV9hreRcSxcPySTLN0oKL81zc8gnNpKOhYw4Yf"
    assert dearmor_raw("RbRLaEY20EoX5Js7sKUuYONmE5bV9hreRcSxcPySTLN0oKL81zc8gnNpKOhYw4Yf") == "this one is much much longer than the other one"
  end

  test "armor messages" do
    assert armor_message("short", "MESSAGE") == "BEGIN SALTPACK MESSAGE.\n8j34xXQ.\nEND SALTPACK MESSAGE.", "Simple message"
    assert armor_message("short", "MESSAGE", [app: "CRYPTOFUN", chars_per_word: 2, words_per_line: 3]) == "BEGIN CRYPTOFUN SALTPACK MESSAGE.\n8j 34 xX\nQ.\nEND CRYPTOFUN SALTPACK MESSAGE.", "Self-selected formatting"
  end

  test "dearmor messages" do
    assert dearmor_message("BEGIN SALTPACK MESSAGE.\n8j34xXQ.\nEND SALTPACK MESSAGE.") == {"MESSAGE", "short"}, "Simple message"
    assert dearmor_message("BEGIN CRYPTOFUN SALTPACK MESSAGE.\n8j34xXQ.\nEND CRYPTOFUN SALTPACK MESSAGE.") == {"MESSAGE", "short"}, "Simple message with application name"

    assert_raise RuntimeError, "Invalid or incomplete message.", fn -> dearmor_message("BEGIN SALTPACK MESSAGE.\n8j34xXQ.\nEND SALTPACK MESSAGE") end
    assert_raise RuntimeError, "Invalid or incomplete message.", fn -> dearmor_message("BEGIN SALTPACK MESSAGE.\n8j34xXQ\nEND SALTPACK MESSAGE.") end
    assert_raise RuntimeError, "Invalid or incomplete message.", fn -> dearmor_message("BEGIN SALTPACK MESSAGE\n8j34xXQ.\nEND SALTPACK MESSAGE.") end
    assert_raise RuntimeError, "Invalid or incomplete message.", fn -> dearmor_message("BEGIN SALTPACK MESSAGE.\n8j34xXQ.\nEND CRYPTOFUN SALTPACK MESSAGE.") end
    assert_raise RuntimeError, "Invalid or incomplete message.", fn -> dearmor_message("BEGIN CRYPTOFUN SALTPACK MESSAGE.\n8j34xXQ.\nEND SALTPACK MESSAGE.") end
  end

end

import unittest
import messages

suite "utils":
  test "escape markdown v2":
     check:
      escapeMarkdownV2(r"C:\Users\azmmonak\bot\src\main.nim(782) main") ==
      r"C:\\Users\\azmmonak\\bot\\src\\main\.nim\(782\) main"

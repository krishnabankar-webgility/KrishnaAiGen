' Starts a program with NO window at all. Task Scheduler's "-WindowStyle Hidden" still flashes a console for a second;
' wscript with window style 0 does not. Usage: wscript.exe //B //Nologo Run-Hidden.vbs <program> <arg> <arg> ...
Dim sh, cmd, i
Set sh = CreateObject("WScript.Shell")
cmd = """" & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1
  cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
sh.Run cmd, 0, False

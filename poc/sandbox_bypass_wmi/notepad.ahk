strCommand := "notepad.exe"
objWMIService := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\" . A_ComputerName . "\root\cimv2")
objProcess := objWMIService.Get("Win32_Process")
Null := ComObjMissing()
VarSetCapacity(processID, 4, 0)
processIDRef := ComObjParameter(0x4|0x4000, &processID)
errReturn := objProcess.Create(strCommand, Null, Null, processIDRef)
msgbox % errReturn . "`n" . NumGet(processID)
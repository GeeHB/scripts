Dim dom 
Set dom = GetObject("WinNT://COMMUNICATION")
WScript.Echo "MinPasswordAge: " &  ((dom.MinPasswordAge) / 86400)
WScript.Echo "MinPasswordLength: " &  dom.MinPasswordLength
WScript.Echo "PasswordHistoryLength: " &  dom.PasswordHistoryLength
WScript.Echo "AutoUnlockInterval: " &  dom.AutoUnlockInterval
WScript.Echo "LockOutObservationInterval: " &  dom.LockOutObservationInterval
WScript.Echo "Attributes: " &  dom.PasswordAttributes
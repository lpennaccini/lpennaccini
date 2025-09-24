' Script VBScript per esecuzione COMPLETAMENTE INVISIBILE
' Questo script non mostra NESSUNA finestra all'utente
' Ideale per distribuzione via GPO o startup scripts

Dim objShell, objFSO, strScriptPath, strNetworkShare, strCommand

' Configurazione
strNetworkShare = "\\server\shared\client_data"
strScriptPath = "collect_client_info_silent.ps1"

' Crea oggetti
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Ottieni il percorso dello script PowerShell
Dim strCurrentPath
strCurrentPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
strScriptPath = strCurrentPath & "\" & strScriptPath

' Verifica che lo script PowerShell esista
If objFSO.FileExists(strScriptPath) Then
    ' Costruisci il comando PowerShell completamente nascosto
    strCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File """ & strScriptPath & """ -DatabasePath """ & strNetworkShare & """ -OutputFormat ""CSV"""
    
    ' Esegui il comando in modalità COMPLETAMENTE NASCOSTA
    ' 0 = Nascosto, False = Non aspetta il completamento
    objShell.Run strCommand, 0, False
    
    ' Log dell'esecuzione (opzionale)
    Dim strLogFile, strLogEntry
    strLogFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\MonitorIT_VBS.log"
    strLogEntry = Now() & " - MonitorIT collection avviata per " & objShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & vbCrLf
    
    ' Scrivi log silenziosamente
    On Error Resume Next
    Dim objFile
    Set objFile = objFSO.OpenTextFile(strLogFile, 8, True)  ' 8 = Append mode
    objFile.Write strLogEntry
    objFile.Close
    On Error GoTo 0
End If

' Pulisci oggetti
Set objShell = Nothing
Set objFSO = Nothing

' Termina silenziosamente
WScript.Quit
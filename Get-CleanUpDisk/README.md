# Disk cleanup

Run the remediation as SYSTEM or an elevated administrator in **64-bit Windows PowerShell**. Edit `$cleanupTypeSelection` to select installed categories; add `'Update Cleanup'` if needed. The default categories are unchanged. The script resets only its `StateFlags0001` profile, sets selected handlers to `2`, fails on missing categories, and checks the process exit code.

Windows Update cleanup depends on the installed handler and eligible superseded components; a successful run does not guarantee reclaimed space. Do not delete WinSxS files manually. Run on a Windows test device before Intune deployment. The registry and cleanmgr behavior cannot be exercised by the macOS offline tests.

Sources: [cleanup handler profile values](https://learn.microsoft.com/en-us/windows/win32/lwef/disk-cleanup), [cleanmgr command](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cleanmgr).

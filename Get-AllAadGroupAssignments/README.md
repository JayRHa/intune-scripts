# Group assignment report

Run the unmodified `.ps1` script with Microsoft Graph PowerShell. Keep its `Param()` block before executable statements; do not prepend legacy `Connect-MSGraph` / `Update-MSGraphEnvironment` calls. This script uses `Connect-MgGraph` and explicit beta request URLs.

The script requests read-only configuration, app, enrollment/service, script and group scopes. Admin consent and an Intune role with access to the policies are still required. For a stale session, run `Disconnect-MgGraph` and reconnect; inspect `(Get-MgContext).Scopes`. Global Administrator status alone does not add scopes to an existing access token. Never paste tokens into an issue.

It follows all Graph result pages, escapes group names, and rejects ambiguous duplicate names. Added coverage includes Settings Catalog / modern Endpoint Security, iOS/Android app protection, managed-device app configuration, and Windows feature/quality update profiles. Update rings are part of device configurations. Conditional Access and managed-app configuration policies are not covered yet; “no assignment” is not proof that a group is unused throughout Entra/Intune. A failed request terminates the report rather than falsely reporting no assignments.

Sources: [Graph groups](https://learn.microsoft.com/en-us/graph/api/group-list?view=graph-rest-1.0), [configuration policies](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfigv2-devicemanagementconfigurationpolicy-list?view=graph-rest-beta), [permissions](https://learn.microsoft.com/en-us/graph/permissions-reference).

Offline tests: `pwsh -NoProfile -File tests/GroupAssignments.Tests.ps1`. These do not prove access to a real tenant.

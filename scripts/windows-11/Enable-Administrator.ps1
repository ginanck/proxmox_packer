# Enable-Administrator.ps1
# Enable the built-in Administrator account and set password
# This script is optional - only run if you want Administrator enabled in the template

Write-Host "Enabling built-in Administrator account..."

# Enable the Administrator account
net user Administrator /active:yes

# Set Administrator password (should match your security requirements)
# In production, use a strong password or leave it disabled
$AdminPassword = "P@ssw0rd123!"  # Change this to your desired password
net user Administrator $AdminPassword

Write-Host "Administrator account enabled and password set"

# Optional: Rename Administrator account for security
# net user Administrator NewAdminName

# Optional: Add Administrator to specific groups (already in Administrators by default)
# net localgroup "Remote Desktop Users" Administrator /add

Write-Host "Administrator account configuration complete"

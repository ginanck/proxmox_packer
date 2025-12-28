<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserLocale>en-US</UserLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <InputLocale>0409:00000409</InputLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>${win_account_ansible_password}</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <DisplayName>${win_account_ansible_username}</DisplayName>
                        <Name>${win_account_ansible_username}</Name>
                        <Description>ansible automation</Description>
                        <Group>Administrators</Group>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Password>
                    <Value>${win_account_ansible_password}</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Username>${win_account_ansible_username}</Username>
                <Enabled>true</Enabled>
                <LogonCount>2</LogonCount>
            </AutoLogon>
            <TimeZone>FLE Standard Time</TimeZone>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Install VirtIO Guest Tools</Description>
                    <RequiresUserInput>false</RequiresUserInput>
                    <CommandLine>cmd.exe /c ${win_iso_virtio_drive}\virtio-win-guest-tools.exe /S /norestart</CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Start QEMU Guest Agent</Description>
                    <RequiresUserInput>false</RequiresUserInput>
                    <CommandLine>powershell -Command &quot;Start-Service -Name &apos;QEMU-GA&apos;&quot;</CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -File ${win_iso_unattend_drive}\Configure-WinRM.ps1</CommandLine>
                    <Order>3</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                    <Description>Configure WinRM for Remote Access</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -File ${win_iso_unattend_drive}\Disable-Security.ps1</CommandLine>
                    <Order>4</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                    <Description>Disable Security Features for Packer Build</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -File ${win_iso_unattend_drive}\Configure-Administrator.ps1</CommandLine>
                    <Order>5</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                    <Description>Configure Built-in Administrator Account</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserLocale>en-US</UserLocale>
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <!-- EFI -->
                        <CreatePartition wcm:action="add">
                            <Size>100</Size>
                            <Type>EFI</Type>
                            <Order>1</Order>
                        </CreatePartition>

                        <!-- MSR -->
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>16</Size>
                            <Type>MSR</Type>
                        </CreatePartition>

                        <!-- Recovery (WinRE) -->
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Size>750</Size>
                            <Type>Primary</Type>
                        </CreatePartition>

                        <!-- Windows (LAST, extendable) -->
                        <CreatePartition wcm:action="add">
                            <Order>4</Order>
                            <Extend>true</Extend>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <!-- EFI -->
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Label>System</Label>
                            <Format>FAT32</Format>
                        </ModifyPartition>

                        <!-- Recovery -->
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>3</PartitionID>
                            <Label>Recovery</Label>
                            <Format>NTFS</Format>
                            <TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID>
                        </ModifyPartition>

                        <!-- Windows -->
                        <ModifyPartition wcm:action="add">
                            <Order>3</Order>
                            <Format>NTFS</Format>
                            <PartitionID>4</PartitionID>
                            <Label>Windows</Label>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <WillWipeDisk>true</WillWipeDisk>
                    <DiskID>0</DiskID>
                </Disk>
                <WillShowUI>OnError</WillShowUI>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>4</PartitionID>
                    </InstallTo>
                    <WillShowUI>OnError</WillShowUI>
                    <InstallToAvailablePartition>false</InstallToAvailablePartition>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>${windows_image_index}</Value>
                        </MetaData>
                    </InstallFrom>
                </OSImage>
            </ImageInstall>
            <UserData>
                <ProductKey>
                    <WillShowUI>Never</WillShowUI>
                    <Key>VK7JG-NPHTM-C97JM-9MPGT-3V66T</Key>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
            </UserData>
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Path>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f</Path>
                    <Order>1</Order>
                    <Description>Disable Windows Defender</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>*</ComputerName>
        </component>
    </settings>

</unattend>

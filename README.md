# Deploy-Package
## PowerShell script for deploying and installing packages on remote computers.

### Description
Simple PowerShell script intended for small to medium package deployments on remote computers. Uses PowerShell Jobs to monitor installations and offers good logging capability for remediation.

### Syntax
Deploy-Package [-ComputerName <String[]>] [-SourcePath <String>] [-Command <string[]>] [-Credential <PSCredential>] [-JobName <string>]

### Parameters
    -ComputerName [String[]]
        Specifies a Computer or list of Computers where the package will be deployed. The script will test for processor architecture and connectivity. Will only attempt to deploy on active computers and generate a log (0_InactiveComputer.log) that lists inactive computers for later use. Also, it will only copy source files related to the Processor Architecture.
    
    -SourcePath [String]
        Specifies the directory of the package to be deployed. Requires a folder structure of ".\x86" and ".\x64" that contain installation files specific for each Processor Architecture, the script will only copy the contents of the folder that matches the computer Processor Architecture. If the installation is the same for both x86 and x64 types, just keep the same files on both folders.

    -Command [String[]]
        Specifies the command or commands that will start the installation on the remote computers. This commands run on the classic Windows Command Prompt and it is executed on the script within "cmd /c <command>". If more than one command is supplied it will be executed in order.

    -Credential [PSCredential]
        Specifies a user account that has permission to perform the deployment.

        Type a user name, such as User01 or Domain01\User01. Or, enter a PSCredential object, such as one generated by the Get-Credential cmdlet. If you type a user name, this cmdlet prompts you for a password.

    -JobName [String]
        Specifies a name for the job that will run the insallations on the remote computers. A child job for each remote computer will be displayed in addition to the main job.

### Examples

#### Example 1
```PowerShell
$params = @{
    ComputerName = @("Computer1","Computer2","Computer3")
    SourcePath = "\\Server1Share\Package1"
    Command = @("install.cmd")
    JobName = "Install-app"
    Credential = (Get-Credential -Message "Please provide your `"Administrator`" credentials:")
}

.\Deploy-Package @params -verbose
```
#### Example 2
```PowerShell
$params = @{
    ComputerName = (Get-content .\ComputerList.txt)
    SourcePath = "\\Server1Share\Package2"
    Command = @("7z.exe x .\compressed.7z -o%temp%","%temp%\install.cmd")
    JobName = "Install-app2"
    Credential = (Get-Credential -Message "Please provide your `"Administrator`" credentials:")
}

.\Deploy-Package @params -verbose
```

## To Do List:
- Create "-Destination" Parameter to allow to choose the Temp folder where souce files will be copied on the remote computers. Currently creates a "C:\\_DE_Temp" folder.
- Add PowerShell requirements
- Add references for sourced functions
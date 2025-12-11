# podman-build.ps1 - Windows PowerShell Podman Build Script
#
# This script automates the process of building and running the Podman container
# with version information dynamically injected at build time.

$ErrorActionPreference = "Stop"

if (-not (Get-Command podman -ErrorAction SilentlyContinue)) {
    Write-Error "Podman is required but not installed or not on PATH."
    exit 1
}

$Script:ComposeCommandName = "podman compose"
$Script:ComposeInvoker = { param([string[]]$Args) & podman compose @Args }

& podman compose version *> $null
if ($LASTEXITCODE -ne 0) {
    if (Get-Command podman-compose -ErrorAction SilentlyContinue) {
        $Script:ComposeCommandName = "podman-compose"
        $Script:ComposeInvoker = { param([string[]]$Args) & podman-compose @Args }
    }
    else {
        Write-Error "Neither 'podman compose' nor 'podman-compose' is available."
        exit 1
    }
}

function Invoke-Compose {
    param([string[]]$Args)
    & $Script:ComposeInvoker @Args
}

if (-not $env:CLI_PROXY_IMAGE -or $env:CLI_PROXY_IMAGE -eq "") {
    $env:CLI_PROXY_IMAGE = "localhost/cli-proxy-api:local"
}
$cliProxyImage = $env:CLI_PROXY_IMAGE

Write-Host "Please select an option:"
Write-Host "1) Run using existing local image (no pull/build)"
Write-Host "2) Build from Source and Run (For Developers)"
$choice = Read-Host -Prompt "Enter choice [1-2]"

switch ($choice) {
    "1" {
        Write-Host "--- Running with existing local image (Podman) ---"
        Write-Host "Using image: $cliProxyImage"
        Invoke-Compose @("-f", "podman-compose.yml", "up", "-d", "--remove-orphans", "--no-build", "--pull", "never")
        Write-Host "Services are starting from local image."
        Write-Host "Run '$Script:ComposeCommandName -f podman-compose.yml logs -f' to see the logs."
    }
    "2" {
        Write-Host "--- Building from Source and Running (Podman) ---"

        $VERSION = (git describe --tags --always --dirty)
        $COMMIT  = (git rev-parse --short HEAD)
        $BUILD_DATE = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

        Write-Host "Building with the following info:"
        Write-Host "  Version: $VERSION"
        Write-Host "  Commit: $COMMIT"
        Write-Host "  Build Date: $BUILD_DATE"
        Write-Host "----------------------------------------"

        $env:CLI_PROXY_IMAGE = $cliProxyImage
        Write-Host "Using image: $cliProxyImage"
        
        Write-Host "Building the Podman image..."
        Invoke-Compose @("-f", "podman-compose.yml", "build", "--build-arg", "VERSION=$VERSION", "--build-arg", "COMMIT=$COMMIT", "--build-arg", "BUILD_DATE=$BUILD_DATE")

        Write-Host "Starting the services..."
        Invoke-Compose @("-f", "podman-compose.yml", "up", "-d", "--remove-orphans", "--pull", "never")

        Write-Host "Build complete. Services are starting."
        Write-Host "Run '$Script:ComposeCommandName -f podman-compose.yml logs -f' to see the logs."
    }
    default {
        Write-Host "Invalid choice. Please enter 1 or 2."
        exit 1
    }
}

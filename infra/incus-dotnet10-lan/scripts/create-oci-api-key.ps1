<#
.SYNOPSIS
    Linux Build Lab用のSSH鍵ペアを作成します。

.DESCRIPTION
    Windows標準のssh-keygenを使用して、
    ed25519形式の秘密鍵と公開鍵を作成します。

    作成された鍵は、現在のユーザーの .ssh ディレクトリへ保存されます。

    生成されるファイル:
      - 秘密鍵: %USERPROFILE%\.ssh\<KeyName>
      - 公開鍵: %USERPROFILE%\.ssh\<KeyName>.pub

    秘密鍵はGitHubなどへ登録しないでください。

.PARAMETER KeyName
    作成するSSH鍵のファイル名です。

    既定値:
      mono-linux-build-lab

.EXAMPLE
    pwsh -ExecutionPolicy Bypass `
      -File .\scripts\create-ssh-key.ps1

.EXAMPLE
    pwsh -ExecutionPolicy Bypass `
      -File .\scripts\create-ssh-key.ps1 `
      -KeyName "my-linux-build-lab"
#>

[CmdletBinding()]
param(
    # 作成するSSH鍵のファイル名
    [string]$KeyName = "mono-linux-build-lab"
)

# エラーが発生した場合は、処理を停止します。
$ErrorActionPreference = "Stop"

# 現在のWindowsユーザーの .ssh ディレクトリを取得します。
$sshDirectory = Join-Path $env:USERPROFILE ".ssh"

# 秘密鍵と公開鍵の保存先を組み立てます。
$privateKeyPath = Join-Path $sshDirectory $KeyName
$publicKeyPath = "$privateKeyPath.pub"

# Windows環境でssh-keygenコマンドを使用できるか確認します。
# 見つからない場合は、OpenSSH Clientのインストールが必要です。
if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    throw "ssh-keygenが見つかりません。WindowsのOpenSSH Clientをインストールしてください。"
}

# .sshディレクトリが存在しない場合は作成します。
if (-not (Test-Path $sshDirectory)) {
    New-Item `
        -Path $sshDirectory `
        -ItemType Directory `
        -Force | Out-Null
}

# 同名の秘密鍵または公開鍵が存在する場合は、
# 既存の鍵を上書きしないように処理を停止します。
if ((Test-Path $privateKeyPath) -or (Test-Path $publicKeyPath)) {
    throw "同名の鍵がすでに存在します: $privateKeyPath"
}

Write-Host "[INFO] SSH鍵を作成します。"
Write-Host "[INFO] 保存先: $privateKeyPath"

# ed25519形式のSSH鍵ペアを作成します。
#
# -t ed25519 : 鍵の形式をed25519に指定
# -C         : 公開鍵に付与するコメント
# -f         : 秘密鍵の保存先
& ssh-keygen `
    -t ed25519 `
    -C $KeyName `
    -f $privateKeyPath

# ssh-keygenが異常終了した場合は、処理を停止します。
if ($LASTEXITCODE -ne 0) {
    throw "SSH鍵の作成に失敗しました。"
}

Write-Host ""
Write-Host "[INFO] SSH鍵を作成しました。"
Write-Host "[INFO] 秘密鍵: $privateKeyPath"
Write-Host "[INFO] 公開鍵: $publicKeyPath"
Write-Host ""
Write-Host "[WARNING] 秘密鍵はGitHubへ登録しないでください。"
Write-Host ""

# OpenTofuやcloud-initへ設定するときに使用できるよう、
# 作成した公開鍵の内容を画面へ表示します。
Write-Host "[INFO] 公開鍵:"
Get-Content $publicKeyPath
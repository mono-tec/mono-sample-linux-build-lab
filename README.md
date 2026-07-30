# Linux Build Lab

「Linux Build Lab」シリーズの記事原稿と、記事で使用するサンプルコードです。

OpenTofuとIncusを使用してUbuntuコンテナを繰り返し構築し、.NET 10アプリのビルド、配布、systemd実行、USBカメラ連携までを段階的に検証します。

## Contents

```text
.
├─ .github/
│  └─ workflows/
│     └─ build-and-release.yml
├─ articles/
│  ├─ linux-build-lab-01-introduction.md
│  ├─ linux-build-lab-02-install-incus.md
│  ├─ linux-build-lab-03-create-ubuntu2404.md
│  ├─ linux-build-lab-04-opentofu-incus.md
│  ├─ linux-build-lab-05-install-dotnet-runtime.md
│  ├─ linux-build-lab-06-dotnet-runtime-environment.md
│  ├─ linux-build-lab-07-deb-systemd.md
│  └─ linux-build-lab-08-incus-usb-camera.md
├─ infra/
│  ├─ incus/
│  ├─ incus-dotnet10/
│  ├─ incus-dotnet10-runtime/
│  ├─ incus-dotnet10-deb/
│  │  ├─ scripts/
│  │  │  └─ create-terraform-tfvars.sh
│  │  ├─ cloud-init.yaml.tftpl
│  │  ├─ main.tf
│  │  ├─ outputs.tf
│  │  ├─ terraform.tfvars.example
│  │  ├─ variables.tf
│  │  └─ README.md
│  └─ incus-usb-camera/
│     ├─ scripts/
│     │  └─ create-terraform-tfvars.sh
│     ├─ cloud-init.yaml.tftpl
│     ├─ main.tf
│     ├─ outputs.tf
│     ├─ terraform.tfvars.example
│     ├─ variables.tf
│     └─ README.md
├─ packaging/
│  ├─ sample-deb/
│  │  ├─ build-deb.sh
│  │  └─ linux-build-lab-sample.service
│  └─ camera-deb/
│     ├─ build-deb.sh
│     └─ linux-build-lab-camera.service
├─ scripts/
│  └─ windows/
│     └─ create-ssh-key.ps1
└─ src/
   ├─ LinuxBuildLab.Sample/
   │  ├─ LinuxBuildLab.Sample.csproj
   │  └─ Program.cs
   └─ LinuxBuildLab.Camera/
      ├─ LinuxBuildLab.Camera.csproj
      └─ Program.cs
```

> 実際のファイル名やディレクトリ構成は、今後の検証内容に合わせて変更する場合があります。

## Series

### Chapter 1

Linux上で.NETアプリを繰り返しビルド・実行できる検証環境として、Linux Build Labを作成する目的を整理します。

### Chapter 2

UbuntuホストへIncusを導入し、コンテナを作成できる状態まで準備します。

### Chapter 3

Incusを使用してUbuntu 24.04コンテナを作成し、基本的な操作を確認します。

### Chapter 4

OpenTofuと`lxc/incus` Providerを使用して、Ubuntu 24.04コンテナの作成と削除をコード化します。

```bash
cd infra/incus

tofu init
tofu fmt
tofu validate
tofu plan
tofu apply
```

検証後は次のコマンドで削除します。

```bash
tofu destroy
```

### Chapter 5

OpenTofuとcloud-initを使用して、Ubuntu 24.04コンテナへ.NET 10開発環境を自動構築します。

### Chapter 6

WindowsからSSH接続できる.NET 10実行環境をOpenTofuで作成し、GitHub Releaseから発行済みアプリを取得して実行します。

### Chapter 7

.NET 10アプリをdebパッケージとして配布し、GitHub Releaseから取得して、systemdのoneshotサービスとして実行します。

対象ディレクトリ：

```text
infra/incus-dotnet10-deb
```

詳しい設定方法と確認手順は、次のREADMEを参照してください。

```text
infra/incus-dotnet10-deb/README.md
```

### Chapter 8

Ubuntuホストへ接続したUSBカメラをIncusコンテナへ割り当て、コンテナ内の.NET 10アプリからJPEG画像を取得します。

対象ディレクトリ：

```text
infra/incus-usb-camera
```

詳しい設定方法と確認手順は、次のREADMEを参照してください。

```text
infra/incus-usb-camera/README.md
```

## Build and Release

GitHub Actionsは、`v*`形式のGitタグがpushされたときに実行されます。

```text
Gitタグ
  ↓
.NETアプリをpublish
  ↓
debパッケージを作成
  ↓
GitHub Releaseへ登録
```

例：

```bash
git tag v0.3.1
git push origin v0.3.1
```

現在の主なRelease成果物は次のとおりです。

```text
LinuxBuildLab.Sample-linux-x64.zip
linux-build-lab-sample_<VERSION>_amd64.deb
linux-build-lab-camera_<VERSION>_amd64.deb
```

.NETアプリとdebパッケージのバージョンは、Gitタグから取得して設定します。

## Sample Applications

### LinuxBuildLab.Sample

Linux上で.NET 10 Runtimeが利用できることを確認するためのコンソールアプリです。

### LinuxBuildLab.Camera

USBカメラからJPEG画像を取得するためのコンソールアプリです。

```text
/var/lib/linux-build-lab-camera/capture.jpg
```

## Debian Packages

### linux-build-lab-sample

サンプルアプリ本体、実行用コマンド、systemd Unitを含みます。

### linux-build-lab-camera

カメラアプリ本体、実行用コマンド、systemd Unitを含みます。

依存関係には、.NET 10 Runtimeと`v4l-utils`を指定します。

## Configuration Policy

環境固有の値は、各OpenTofu構成ディレクトリにある`terraform.tfvars`で管理します。

```text
terraform.tfvars.example
  ↓
scripts/create-terraform-tfvars.sh
  ↓
terraform.tfvars
```

`terraform.tfvars`には、次のような環境固有情報が含まれます。

- UbuntuホストのLANインターフェース
- コンテナのIPv4アドレス
- SSH公開鍵
- USBカメラのデバイスパス
- GitHub Releaseから取得するパッケージ名
- パッケージのバージョン

`terraform.tfvars`はGitへ登録しません。

パッケージの既定バージョンは、各構成の`variables.tf`で管理します。

```hcl
variable "package_version" {
  type    = string
  default = "0.3.1"
}
```

設定生成スクリプトは、この既定値を読み取って`terraform.tfvars`を作成します。

## Git Management

Gitへ登録する主なファイル：

```text
.terraform.lock.hcl
*.tf
*.tftpl
terraform.tfvars.example
scripts/
README.md
src/
packaging/
articles/
.github/workflows/
```

Gitへ登録しない主なファイル：

```text
.terraform/
terraform.tfvars
terraform.tfstate
terraform.tfstate.*
artifacts/
publish/
bin/
obj/
```

## Notes

- `.tfstate`、`terraform.tfvars`、`artifacts/`はGit管理対象外です。
- SSH秘密鍵はGitへ登録しないでください。
- cloud-initは基本的にコンテナの初回起動時に実行されます。
- cloud-initの変更を確認する場合は、既存コンテナを削除して再作成してください。
- USBカメラのデバイス名や`video`グループのGIDは、利用環境に合わせて確認してください。
- Provider、.NET、Ubuntu、debパッケージのバージョンは、検証時点の構成に合わせて調整してください。
- ブログ本文では構成と確認結果を中心に扱い、詳細な実行手順は各ディレクトリのREADMEへまとめています。

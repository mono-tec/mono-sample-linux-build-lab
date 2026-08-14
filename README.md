# Linux Build Lab

「Linux Build Lab」シリーズの記事原稿と、記事で使用するサンプルコードです。

OpenTofuとIncusを使用してUbuntuコンテナを繰り返し構築し、.NET 10アプリのビルド、配布、systemd実行、USBカメラ連携までを段階的に検証します。

また、GitHub Actionsを使用して、

- .NETアプリのpublish
- SBOM生成
- OSSライセンス情報生成
- debパッケージ作成
- GitHub Releaseへの公開

までを自動化しています。

---

## Contents

```text
.
├─ .github/
│  └─ workflows/
│     └─ dotnet-build.yml
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
│  ├─ linux/
│  │  └─ generate-linux-compliance.sh
│  └─ windows/
│     └─ create-ssh-key.ps1
├─ src/
│  ├─ LinuxBuildLab.Sample/
│  │  ├─ LinuxBuildLab.Sample.csproj
│  │  └─ Program.cs
│  └─ LinuxBuildLab.Camera/
│     ├─ LinuxBuildLab.Camera.csproj
│     └─ Program.cs
├─ .gitattributes
├─ .gitignore
├─ LICENSE
└─ README.md
```

> 実際のファイル名やディレクトリ構成は、今後の検証内容に合わせて変更する場合があります。

---

## Series

### Chapter 1

Linux上で.NETアプリを繰り返しビルド・実行できる検証環境として、Linux Build Labを作成する目的を整理します。

### Chapter 2

UbuntuホストへIncusを導入し、コンテナを作成できる状態まで準備します。

### Chapter 3

Incusを使用してUbuntu 24.04コンテナを作成し、基本的な操作を確認します。

### Chapter 4

OpenTofuとIncus Providerを使用して、Ubuntu 24.04コンテナの作成と削除をコード化します。

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

WindowsからSSH接続できる.NET 10実行環境をOpenTofuで作成し、発行済みアプリを取得して実行します。

### Chapter 7

.NET 10アプリをdebパッケージとして配布し、systemdのoneshotサービスとして実行します。

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

---

## Build and Release

GitHub Actionsは、`v*`形式のGitタグがpushされたときに実行されます。

```text
Gitタグ
  ↓
.NETアプリをpublish
  ↓
SBOMを生成
  ↓
OSSライセンス情報を生成
  ↓
debパッケージを作成
  ↓
GitHub Releaseへ登録
```

例：

```bash
git tag v0.3.4
git push origin v0.3.4
```

Gitタグの、

```text
v0.3.4
```

から、

```text
0.3.4
```

を取得し、.NETアプリとdebパッケージのバージョンとして使用します。

現在の主なRelease成果物は次のとおりです。

```text
linux-build-lab-sample_<VERSION>_amd64.deb
linux-build-lab-camera_<VERSION>_amd64.deb
```

GitHub ActionsのWorkflowは次のファイルにあります。

```text
.github/workflows/dotnet-build.yml
```

---

## SBOM and OSS License Information

GitHub Actionsでは、debパッケージ作成時にSBOMとOSSライセンス情報も生成します。

生成した情報は、最終的にdebパッケージへ含めます。

### Microsoft sbom-tool

SPDX形式のSBOM生成に使用します。

- Repository: https://github.com/microsoft/sbom-tool
- License: MIT

### ONOT

生成したSBOMをもとに、OSSライセンス情報をまとめた`THIRD-PARTY-NOTICES.md`の生成に使用します。

- Repository: https://github.com/sktelecom/onot
- Version: 1.1.2
- License: Apache License 2.0

GitHub Actionsでは、各アプリごとに次のファイルを生成します。

```text
LICENSE
THIRD-PARTY-NOTICES.md
sbom.spdx.json
```

`LICENSE`は、このRepository自身のライセンスです。

`THIRD-PARTY-NOTICES.md`は、SBOMをもとに生成したOSSライセンス情報です。

`sbom.spdx.json`は、SPDX形式のSBOMです。

---

## Debian Packages

### linux-build-lab-sample

.NET 10のサンプルアプリをdebパッケージとして配布します。

主な内容は次のとおりです。

```text
/opt/linux-build-lab-sample/
/usr/bin/linux-build-lab-sample
/usr/lib/systemd/system/linux-build-lab-sample.service
```

ライセンス・SBOM関連ファイルは次の場所へ配置します。

```text
/usr/share/doc/linux-build-lab-sample/
├── LICENSE
├── THIRD-PARTY-NOTICES.md
└── sbom.spdx.json
```

systemdのoneshotサービスとして実行できます。

```bash
sudo systemctl start linux-build-lab-sample.service
```

---

### linux-build-lab-camera

USBカメラからJPEG画像を取得する.NET 10アプリをdebパッケージとして配布します。

主な内容は次のとおりです。

```text
/opt/linux-build-lab-camera/
/usr/bin/linux-build-lab-camera
/usr/lib/systemd/system/linux-build-lab-camera.service
```

ライセンス・SBOM関連ファイルは次の場所へ配置します。

```text
/usr/share/doc/linux-build-lab-camera/
├── LICENSE
├── THIRD-PARTY-NOTICES.md
└── sbom.spdx.json
```

依存関係には、次のパッケージを指定しています。

```text
dotnet-runtime-10.0
v4l-utils
```

systemdから実行すると、USBカメラからJPEG画像を取得します。

```text
/var/lib/linux-build-lab-camera/capture.jpg
```

---

## Ubuntu Environment Validation

GitHub Actionsで作成したdebパッケージは、新規Ubuntu環境へインストールして確認しています。

Sample版では、次の内容を確認しました。

```text
debパッケージのインストール
systemd oneshotサービスの実行
LICENSEの配置
THIRD-PARTY-NOTICES.mdの配置
SPDX SBOMの配置
```

Camera版についても同様に確認し、USBカメラからJPEG画像を生成できることまで確認しています。

インストール済みファイルは、次のコマンドで確認できます。

```bash
dpkg -L linux-build-lab-sample
```

または、

```bash
dpkg -L linux-build-lab-camera
```

---

## Sample Applications

### LinuxBuildLab.Sample

Linux上で.NET 10 Runtimeが利用できることを確認するためのコンソールアプリです。

systemdのoneshotサービスとして実行し、OS、CPUアーキテクチャ、.NET Runtimeなどの情報を出力します。

### LinuxBuildLab.Camera

USBカメラからJPEG画像を取得するためのコンソールアプリです。

内部では`v4l2-ctl`を使用します。

出力先：

```text
/var/lib/linux-build-lab-camera/capture.jpg
```

---

## Release Package Acquisition

検証環境では、GitHub Releasesのlatest APIを使用して最新debパッケージを取得します。

例：

```text
https://api.github.com/repos/mono-tec/mono-sample-linux-build-lab/releases/latest
```

cloud-init内で対象パッケージ名を定義し、Release Assetsから次の形式に一致するdebを取得します。

```text
linux-build-lab-sample_<VERSION>_amd64.deb
```

または、

```text
linux-build-lab-camera_<VERSION>_amd64.deb
```

検証環境では過去バージョンの再現ではなく、

```text
現在の最新パッケージが
新規Ubuntu環境へ正常に導入・実行できるか
```

を確認することを目的としています。

そのため、`terraform.tfvars`ではパッケージ名やパッケージバージョンを管理しません。

---

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

```text
UbuntuホストのLANインターフェース
コンテナのIPv4設定
SSH公開鍵
USBカメラのデバイス情報
```

`terraform.tfvars`はGitへ登録しません。

パッケージ名やパッケージバージョンは、`terraform.tfvars`では管理しません。

debパッケージの取得については、cloud-initからGitHub Releasesのlatest APIを使用します。

---

## Network Configuration

検証用コンテナでは、Incusの管理用NICとは別にmacvlan NICを追加できます。

例：

```text
eth0
  Incus管理ネットワーク

eth1
  macvlan
  外部LAN接続
```

`eth1`のIPv4設定はcloud-initからNetplan設定を作成します。

DHCPまたは固定IPv4を使用できます。

Netplan適用時にはネットワークが一時的に再構成されるため、GitHub Releasesへのアクセスには`curl`のリトライ処理を使用しています。

---

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
LICENSE
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
private-scripts/
```

---

## Line Ending Policy

Linux Shell ScriptはLF、Windows PowerShell ScriptはCRLFとして管理します。

`.gitattributes`では次のように設定しています。

```text
*.sh text eol=lf
*.ps1 text eol=crlf
```

Linux Shell ScriptがCRLFになると、

```text
/usr/bin/env: ‘bash\r’: No such file or directory
```

のようなエラーになる場合があるため、Linux向けShell ScriptはLFで管理します。

---

## License

このRepositoryはMIT Licenseで公開しています。

詳細は次のファイルを参照してください。

```text
LICENSE
```

---

## Notes

- `.tfstate`、`terraform.tfvars`、`artifacts/`はGit管理対象外です。
- SSH秘密鍵はGitへ登録しないでください。
- cloud-initは基本的にコンテナの初回起動時に実行されます。
- cloud-initの変更を確認する場合は、既存コンテナを削除して再作成してください。
- USBカメラのデバイス名や`video`グループの設定は、利用環境に合わせて確認してください。
- Provider、.NET、Ubuntu、debパッケージの構成は、検証時点の環境に合わせて調整してください。
- GitHub Releasesから取得するdebパッケージは、latest Releaseを使用します。
- SBOMおよびOSSライセンス情報は、利用しているOSSコンポーネントやライセンスを確認するための資料として生成しています。
- ブログ本文では構成と確認結果を中心に扱い、詳細な実行手順は各ディレクトリのREADMEへまとめています。

# Linux Build Lab Chapters 4-6

「Linux Build Lab」第4章から第6章の記事原稿と、記事で使用するサンプルコードです。

## Contents

```text
.
├─ articles/
│  ├─ linux-build-lab-03-create-ubuntu2404.md
│  ├─ linux-build-lab-04-opentofu-incus.md
│  ├─ linux-build-lab-05-install-dotnet-runtime.md
│  └─ linux-build-lab-06-create-deb-package.md
├─ infra/
│  └─ incus/
│     ├─ main.tf
│     ├─ variables.tf
│     └─ outputs.tf
├─ packaging/
│  └─ deb/
│     ├─ build-deb.sh
│     └─ linux-build-lab-sample.service
└─ src/
   └─ LinuxBuildLab.Sample/
      ├─ LinuxBuildLab.Sample.csproj
      └─ Program.cs
```

## Chapter 4

OpenTofuと`lxc/incus` Providerを使用して、Ubuntu 24.04コンテナを作成します。

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

## Chapter 5

作成したUbuntu 24.04コンテナへ.NET 10 Runtimeを導入します。

```bash
sudo incus shell ubuntu2404-tofu
apt-get update
apt-get install -y dotnet-runtime-10.0
dotnet --list-runtimes
```

## Chapter 6

.NET 10 SDKと`dpkg-deb`を使用して、サンプルアプリの`.deb`パッケージを作成します。

```bash
apt-get update
apt-get install -y dotnet-sdk-10.0 dpkg-dev
./packaging/deb/build-deb.sh
```

作成先

```text
artifacts/packages/linux-build-lab-sample_1.0.0_amd64.deb
```

## GitHubへ登録する例

```bash
git init
git add .
git commit -m "Add Linux Build Lab chapters 4 to 6"
git branch -M main
git remote add origin <YOUR_REPOSITORY_URL>
git push -u origin main
```

## Notes

- `.tfstate`と`artifacts/`はGit管理対象外です。
- 第4章から第6章は、実機での最終検証前の原稿として`published: false`にしています。
- Providerやパッケージのバージョンは、検証時点の公式情報に合わせて調整してください。

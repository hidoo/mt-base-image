# mt-base-image

[![Build and Push Docker Images](https://github.com/hidoo/mt-base-image/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/hidoo/mt-base-image/actions/workflows/build-and-push.yml)

Perl PSGI 環境で Movable Type を動作させる開発用の Docker イメージ。Perl 5.16 と 5.32 に対応。

## 利用方法

### インストール

```bash
docker pull ghcr.io/hidoo/mt-base-image:perl-5.32-latest
```

### アプリケーションの配置

`/app/movabletype` ディレクトリに Movable Type のパッケージを配置してください。

```Dockerfile
FROM ghcr.io/hidoo/mt-base-image:perl-5.32-latest

# Set up requires packages
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    zip \
    unzip \
    && apt-get autoclean -y \
    && rm -r /var/lib/apt/lists/*

# Install movabletype
ARG MOVABLETYPE_VERSION
COPY ./files/${MOVABLETYPE_VERSION}.zip /tmp/
RUN unzip -d /tmp /tmp/${MOVABLETYPE_VERSION}.zip \
    && cp -pR /tmp/${MOVABLETYPE_VERSION}/* /app/movabletype \
    && rm -rf /tmp/${MOVABLETYPE_VERSION} \
    && rm -rf /tmp/${MOVABLETYPE_VERSION}.zip \
    && chmod +x /app/movabletype/*.cgi \
    && chmod +x /app/movabletype/tools/run-periodic-tasks \
    && chmod 775 /app/movabletype/themes \
    && chmod 775 /app/movabletype/plugins \
    && chmod 775 /app/movabletype/mt-static \
    && chmod 775 /app/movabletype/mt-static/support
```

## 開発

## 技術スタック

+ **Perl**: 5.16.3 / 5.32.1 (perlbrew でソースからコンパイル)
+ **ベースイメージ**: debian:bullseye+slim
+ **アプリケーションサーバー**: Starman (workers: 5, port: 5000)
+ **プロセス管理**: Proclet (Perl 製 foreman 互換)
+ **依存管理**: cpanfile

## 前提条件

+ Docker 20.10+
+ Docker Compose v2+

### イメージのビルド

```bash
# 両バージョンをビルド
./scripts/build-all.sh

# 個別にビルド
docker build -f perl-5.32/Dockerfile -t mt-base-image:perl-5.32 .
docker build -f perl-5.16/Dockerfile -t mt-base-image:perl-5.16 .
```

### コンテナの起動

```bash
# docker compose で両バージョン起動
docker compose up -d

# Perl 5.16: http://localhost:5016/
# Perl 5.32: http://localhost:5032/
```

### 動作確認

```bash
curl http://localhost:5016/
curl http://localhost:5032/
```

### 開発用一括チェック

lint、ビルド、コンテナ起動、HTTP レスポンス、モジュール読み込み、プロセス数を一括で検証します。

```bash
./scripts/dev.sh
```

## プロジェクト構成

```
project-root/
├── perl-5.16/
│   ├── Dockerfile           # Perl 5.16 マルチステージビルド
│   └── .dockerignore
├── perl-5.32/
│   ├── Dockerfile           # Perl 5.32 マルチステージビルド
│   └── .dockerignore
├── common/
│   ├── cpanfile             # 共通の CPAN 依存定義
│   ├── cpanfile.snapshot    # 依存関係の固定 (生成ファイル)
│   ├── Procfile             # Proclet プロセス定義
│   └── entrypoint.sh        # コンテナ起動スクリプト
├── app/movabletype/
│   └── mt.psgi              # PSGI エントリポイント
├── scripts/
│   ├── config.sh            # 共通設定 (IMAGE_NAME, PERL_VERSIONS)
│   ├── build-all.sh         # 両バージョンビルドスクリプト
│   ├── generate-snapshot.sh # cpanfile.snapshot 生成
│   └── dev.sh               # 開発用メインスクリプト (lint・ビルド・検証)
├── compose.yml
└── README.md
```

## ビルドスクリプト

### 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `IMAGE_NAME` | `mt-base-image` | イメージ名 |

### 使用例

```bash
./scripts/build-all.sh
```

## cpanfile.snapshot の生成

```bash
# Perl 5.32 イメージを使用して生成 (デフォルト)
./scripts/generate-snapshot.sh

# Perl バージョンを指定
./scripts/generate-snapshot.sh 5.16
```

### Lint

```bash
# Dockerfile の検証
hadolint perl-5.16/Dockerfile perl-5.32/Dockerfile

# シェルスクリプトの検証
shellcheck scripts/*.sh common/entrypoint.sh
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Perl の PSGI アプリケーション (Movable Type) が動作する開発用 Docker イメージ。
Perl 5.16.3 と 5.32.1 の2バージョンに対応し、Starman で起動、Proclet でプロセス管理を行う。

## 技術スタック

- **言語**: Perl 5.16.3 / 5.32.1 (perlbrew でソースからコンパイル)
- **ベースイメージ**: debian:bullseye-slim
- **アプリケーションサーバー**: Starman (PSGI)
- **プロセス管理**: Proclet (Perl 製 foreman 互換)
- **コンテナ**: Docker (マルチアーキテクチャ: linux/amd64, linux/arm64)
- **依存管理**: cpanfile + cpanfile.snapshot

## ディレクトリ構成

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
│   ├── build-all.sh         # 両バージョンビルドスクリプト
│   ├── generate-snapshot.sh # cpanfile.snapshot 生成
│   └── verify.sh            # ビルド後検証スクリプト
├── compose.yml
└── README.md
```

## Dockerfile 設計方針

### イメージサイズ最適化戦略

1. **マルチステージビルド**: ビルド用 (builder) と実行用 (runtime) のステージを分離
2. **ベースイメージ**: debian:bullseye-slim + perlbrew (perl:X.XX-slim は 5.16 が EOL で存在しないため)
3. **不要ファイル削除**: apt キャッシュ、テストファイルなどを削除
4. **レイヤー最適化**: RUN コマンドを統合

## Proclet 設定

`common/Procfile` でプロセスを定義。`entrypoint.sh` が `proclet start` を呼び出す。

- Starman: workers 5, port 5000
- ログ: /dev/stderr へ出力

## cpanfile 依存モジュール

依存定義は `common/cpanfile` を参照。変更時の注意事項:

- `DBD::mysql == 4.052`: MySQL 5.x 対応の最終バージョン。変更不可
- `Module::Pluggable >= 5.2`: `== 5.2` は CPAN から削除済みのため `>=` で指定
- `Proclet`: プロセス管理の必須依存。削除不可

## cpanfile.snapshot の管理

`scripts/generate-snapshot.sh` で cpanfile.snapshot を生成する。

```bash
# Perl 5.32 のビルダーステージを使って生成 (デフォルト)
./scripts/generate-snapshot.sh

# Perl バージョンを指定
./scripts/generate-snapshot.sh 5.16
```

cpanfile を変更した場合は snapshot の再生成が必要。ビルダーステージ (`--target builder`) を使う理由は、ランタイムステージに build-essential がなく Carton のインストールが失敗するため。

## Lint / Format

- Dockerfile は Hadolint で検証する
- ShellScript は shellcheck で検証する
- Perl は Perl::Critic で検証し、Perl::Tidy で整形する

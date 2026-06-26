# Symbol Node on Dokploy (Shoestring Based)

Dokploy 上で Symbol のフルノード（Peer Node, Broker, REST Gateway, MongoDB）を、完全自動かつ頑健にデプロイするための Docker Compose テンプレートです。

最新の構築ツール **Shoestring** の仕様変更や、コンテナ環境特有のレースコンディション（起動タイミングの競合）をすべてクリアした最適化済みの構成となっています。

## 🚀 特徴（インフラ最適化ポイント）

- **レプリカセット自動待機ロジック**: MongoDB が完全に Ready になるまでヘルスチェックを回してから `rs0` を初期化するため、初回起動時のコンテナ即死ループが起きません。
- **データ領域の完全分離**: ロック競合（`LockOpen failed: 17`）を防ぐため、Broker と Node のデータボリュームを完全に切り離しています。
- **不揮発性ロックファイルの自動掃除**: 異常終了時に残って再起動を阻害する古い `.lock` 残骸を、コンテナ起動時に自動パージします。
- **証明書自動探索配送**: Shoestring が生成する暗号化証明書（`ca.pubkey.pem` 等）を自動で見つけ出し、本番コンテナへ安全にマウント配送します。

## 📂 構成ファイル

```text
├── docker-compose.yml      # 全サービスの設定とボリューム定義
└── initializer/
    ├── Dockerfile          # Shoestring 実行用環境
    └── entrypoint.sh       # 設定自動生成＆ボリューム配送スクリプト
```

## 🛠️ 前提条件・準備するもの

1. **Dokploy** がインストールされた VPS（Ubuntu等）
2. **ドメイン名**（例: `node.apps.neoflow.jp`）
3. **各種秘密鍵（HEX 64文字）**
   - `MAIN_PRIVATE_KEY`（必須・ノードの主勘定）
   - `VRF_PRIVATE_KEY`
   - `REMOTE_PRIVATE_KEY`
   - `VOTING_PRIVATE_KEY`

## ⚙️ 構築手順

### 1. DNS とファイアウォールの設定
- **DNS設定**: 使用するドメイン（Aレコード）を VPS のグローバルIPアドレスに向けて設定します。
- **ファイアウォール開放**: VPS のインバウンド（受信）ルールで、以下のポートを開放してください。
  - `80 / 443` (TCP): Dokploy / SSL 認証用
  - `7900` (TCP): Symbol P2P 通信用（**必須**）

### 2. Dokploy でのアプリケーション作成
1. Dokploy にログインし、**「Create Compose」** から新しいプロジェクトを作成します。
2. リポジトリ（GitHub等）と連携し、本リポジトリの `docker-compose.yml` を読み込ませます。

### 3. 環境変数の登録
Dokploy の **「Environment」** タブを開き、以下の環境変数をすべて登録します。

| 変数名 | 説明 | 例 |
| :--- | :--- | :--- |
| `DOMAIN_NAME` | ノードを公開するドメイン | `node.apps.neoflow.jp` |
| `MAIN_PRIVATE_KEY` | メインアカウントの秘密鍵 | `(64文字のHEX)` |
| `VRF_PRIVATE_KEY` | VRFアカウントの秘密鍵 | `(64文字のHEX)` |
| `REMOTE_PRIVATE_KEY` | リモートアカウントの秘密鍵 | `(64文字のHEX)` |
| `VOTING_PRIVATE_KEY` | 投票アカウントの秘密鍵 | `(64文字のHEX)` |
| `NODE_NAME` | ノードの表示名（任意） | `MyDokployNode` |
| `SYMBOL_NETWORK` | ネットワーク（デフォルト: mainnet）| `mainnet` |

### 4. 外部ドメイン（REST API）の紐付け
1. Dokploy の該当 Compose 画面で **「Domains」** タブを開きます。
2. **「Add Domain」** をクリックし、以下を設定します。
   - **Domain**: 設定したドメイン（例: `node.apps.neoflow.jp`）
   - **Service**: `rest-gateway`
   - **Container Port**: `3000`
   - **Certificate (SSL)**: Let's Encrypt にチェックを入れて有効化

### 5. デプロイの実行
「Environment」および「Domains」の設定が完了したら、**「Deploy」** をクリックします。

`initializer` と `mongo-init` が全自動で足回りを構築し、正常終了（Exited 0）した後に本番ノード群が一斉に立ち上がります。

## 🔍 動作確認

デプロイ完了後、数分待ってからブラウザや `curl` で以下にアクセスしてください。
- `https://<あなたのドメイン>/node/info`

ノードのステータスが JSON で綺麗に返ってくれば、無事に世界中のピアと接続され、ブロックチェーンの同期が開始されています。

## 📄 ライセンス

[MIT License](LICENSE)
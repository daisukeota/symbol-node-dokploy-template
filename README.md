# Symbol Node Dokploy Template

Dokploy上でSymbolのAPI/Peer（Dual）ノードを安全、高速、かつメンテナンスフリーでデプロイするためのDocker Composeテンプレートです。

Shoestringによる初期設定の自動化、不安定なピアからの切断に対する自動フォールバックパッチ、およびDokployのネットワーク仕様に最適化されたルーティングが組み込まれています。

## 🚀 特徴

- **Dokploy最適化ネットワーク**: `network_mode`の競合や循環依存を完全に回避し、Symbol特有の厳格なmTLS/SNI検証を100%ネイティブにクリアします。
- **耐障害性初期化スクリプト**: セットアップ中に外部の接続先ピアが突然切断（Drop）しても、自動的に超安定なRESTノード（allnodes等）へ切り替えて処理を続行するパッチが内蔵されています。
- **完全データ保護**: 設定ファイルや証明書が更新されても、それまでに同期したギガバイト単位のブロックデータ（MongoDB/Catapultデータ）は安全に維持されます。

## 🛠️ 事前準備（環境変数の設定）

Dokployのプロジェクト管理画面の **「Environment」** タブで、以下の環境変数を必ず設定してください。

| 環境変数名 | 設定値の例 / 説明 |
| :--- | :--- |
| `SYMBOL_NETWORK` | `mainnet` (デフォルト) または `testnet` |
| `NODE_NAME` | あなたのノードのニックネーム（例: `My-Awesome-SymbolNode`） |
| `DOMAIN_NAME` | ノードを外部公開するDNSドメイン（例: `node.example.com`） |
| `MAIN_PRIVATE_KEY` | ノードのメインアカウントの秘密鍵（64文字の16進数） |
| `VRF_PRIVATE_KEY` | VRFアカウントの秘密鍵 |
| `REMOTE_PRIVATE_KEY` | リモートアカウントの秘密鍵 |
| `VOTING_PRIVATE_KEY` | 投票用アカウントの秘密鍵（※任意、ハーベスティングのみなら空でも可） |

## 📦 デプロイ手順

### 1. リポジトリの紐付け
Dokployの「Compose」サービス作成画面で、このリポジトリのGit URLを指定します。
`https://github.com/daisukeota/symbol-node-dokploy-template.git`

### 2. 環境変数の入力
上記の「事前準備」に記載された環境変数をすべて入力し、保存します。

### 3. ⚠️【超重要】ドメインの設定（ルーティングの肝）
Dokployの **「Domains」** 設定を開き、あなたのドメイン（例: `node.example.com`）を割り当てます。その際、ターゲットとなるサービスとポートを**必ず以下のように指定してください。**

- **Service:** `db`
- **Port:** `3000`

> 💡 **なぜ `rest-gateway` ではなく `db` なのか？**
> Dokployはドメインを設定したサービスに対し、裏側で強制的に専用のネットワークを注入する仕様があります。
> 本テンプレートでは、Symbolの厳格な暗号化通信（mTLS）をパスさせるため、全コンテナのネットワーク空間を`db`に一本化（同居）させています。ルーティングの親玉である`db`の3000番ポート宛てのWEBトラフィックは、同居している`rest-gateway`が自動的にネイティブキャッチするため、外からは完全にAPIサーバーとして正しく機能します。

### 4. デプロイの実行
設定が完了したら、 **`[Deploy]`** ボタンをクリックします。
初期化（initializer）コンテナが走り、設定ファイルが自動生成された後、ノード本体とAPIサーバーが一斉に起動します。

## 🔍 動作確認

デプロイ完了後、C++ノード本体がデータベースの検証等を行って完全に目覚めるまで **1〜2分ほど** かかります。起動直後はAPI（3000番）へのアクセスで `503 Service Unavailable` が出ることがありますが、これは正常な時間差です。

のんびり待った後、ブラウザやターミナルから以下にアクセスしてください。
`https://あなたのDOMAIN_NAME/node/info`

以下のように、あなたが指定した `friendlyName` と `host` が美しく刻まれたJSONが返ってくれば、無事に世界へ大開通です！

```json
{
  "version": 16777993,
  "publicKey": "...",
  "roles": 7,
  "port": 7900,
  "host": "node.example.com",
  "friendlyName": "My-Awesome-SymbolNode"
}
```

## 🧹 ブロックデータを消さずに設定（ノード名など）だけを更新する方法

「ノード名を変更したい」「環境変数を書き換えた」という場合、これまで同期した巨大なブロックデータを一切失うことなく、設定ファイルだけを安全にリフレッシュする手順です。

1. Dokploy画面で **`[Stop]`** をクリックし、スタックを停止させます。
2. VPSのターミナルにSSHでログインし、以下のコマンドを実行して**設定ボリュームの3つだけを狙い撃ちで削除**します。
   ```bash
   docker rm $(docker ps -a -q --filter name=symbolnode) 2>/dev/null || true
   docker volume rm プロジェクト名_symbol_startup プロジェクト名_symbol_userconfig プロジェクト名_symbol_certificates
   ```
   *(※ 生データである `symbol_data_node` と `mongodb_data` は絶対に対象に入れないでください)*
3. Dokploy画面に戻り、再び **`[Deploy]`** をクリックします。
4. 新しい環境変数を吸い込んだ設定ファイルが再生成され、ブロックデータは前回の続き（数GB〜）から何事もなかったかのように爆速で同期が再開されます。

## 📄 ライセンス

MIT License
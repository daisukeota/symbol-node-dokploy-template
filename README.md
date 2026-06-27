# Symbol Node on Dokploy Template

Shoestringを使用したSymbolノードを、Dokploy (Docker Compose) 環境で安全かつ堅牢に運用するためのテンプレートリポジトリです。

データの永続化ボリュームと設定・証明書ボリュームを完全に分離しているため、ブロックデータを維持したままノード設定や環境変数を安全にリフレッシュできます。

---

## ⚙️ 環境変数設定 (Dokploy Environment)

Dokployの「Environment」タブで以下の変数を設定してください。

| 変数名 | 必須 | 説明 | 設定例 |
| :--- | :---: | :--- | :--- |
| `SYMBOL_NETWORK` | | ネットワークの指定 (`mainnet` または `testnet`) | `mainnet` |
| `DOMAIN_NAME` | Yes | ノードのSSL/TLS通信に使用する公開ドメイン名 | `node.apps.neoflow.jp` |
| `NODE_NAME` | | 他のピアから視認できるフレンドリーネーム | `Neoflow-Symbol-Node` |
| `MAIN_PRIVATE_KEY` | Yes | メインウォレットの秘密鍵 (HEX 64文字) | `(あなたの秘密鍵)` |
| `BENEFICIARY_ADDRESS` | | 委任ハーベスト報酬のノードボーナスを受け取るアドレス | `ND64MJ37DAYIEWBBYB5ZT5BXTCWSKGH5UDJVYDQ` |

> ⚠️ **Shoestring仕様に関する注意点**
> 過去の `symbol-bootstrap` 時代とは異なり、`VRF`、`REMOTE`、`VOTING` などのサブ鍵（秘密鍵）を明示的に指定する必要はありません。Shoestringのセットアップ時にコンテナ内部で自動的に新規生成され、メインアカウントに自動的にリンク合意トランザクションが発行されるクリーンな設計思想になっています。

---

## 🚀 初回デプロイ手順

- [ ] 1. 独自ドメインを取得し、サーバーのグローバルIPにDNS（Aレコード）を設定します。
- [ ] 2. 外部からノードへの通信を受け付けるため、ルーターやファイアウォールで **7900ポート** および **3000ポート** を解放します。
- [ ] 3. Dokployの管理画面から新しい「Compose」アプリケーションを作成します。
- [ ] 4. 本リポジトリの `docker-compose.yml` をDokployに貼り付けます。
- [ ] 5. 上記の「環境変数設定」に従って変数をすべて入力します。
- [ ] 6. `[Deploy]` ボタンをクリックします。初回のみ、自動的にブロック1からの同期（または初期シードの展開）が開始されます。

---

## 🧹 ブロックデータを消さずに設定（環境変数やノード名）を更新する方法

「ノード名を変更したい」「環境変数を書き換えた」「ベネフィシャリ（報酬受取アドレス）を設定・変更した」という場合、これまで同期した巨大なブロックデータ（MongoDB含む）を一切失うことなく、設定ファイルや証明書だけを安全にリフレッシュする手順です。

永続化データはDokploy側の独立したVolumesで厳重に保護されているため、以下の手順で安全に設定の再注入が可能です。

### 1. スタックの停止
Dokployの管理画面で、対象プロジェクトの **`[Stop]`** をクリックし、稼働中のすべてのコンテナを一時停止させます。

### 2. 環境変数の書き換え
Dokployの **「Environment」** タブを開き、追加・変更したい項目（`BENEFICIARY_ADDRESS` や `NODE_NAME` など）を書き換えて保存します。

### 3. 停止したコンテナ（殻）の強制削除
古い設定情報をメモリやキャッシュに掴んでいるコンテナの殻を削除して完全に解放します。VPSのターミナル（SSH）にログインし、以下の強制一斉削除コマンドを実行します。

```bash
docker rm -f $(docker ps -a -q --filter name=symbolnode) 2>/dev/null || true
```

### 4. 設定ボリュームのみを「狙い撃ち」削除
ここが最も重要なポイントです。生データボリュームを**絶対に触らず**、Shoestringが再ビルドを行うための設定用ボリューム3つだけを削除します。

```bash
# ※ご自身のDokployスタック名（サフィックス）に合わせてプレフィックスを調整してください
docker volume rm \
  neoflowjp-symbolnode-wt0xym_symbol_startup \
  neoflowjp-symbolnode-wt0xym_symbol_userconfig \
  neoflowjp-symbolnode-wt0xym_symbol_certificates
```

> 🛡️ **データの完全保護について**
> このコマンドを実行しても、同期データの実体である `_symbol_data_node` ボリューム、および `_mongodb_data` ボリュームには1ミリも触れないため、これまでの同期の歴史は100%安全に維持されます。

### 5. 再デプロイ（最新設定の自動インジェクション）
Dokployのメイン画面に戻り、再び **`[Deploy]`** をクリックします。

新しく入力した環境変数、最短ループに固定された内部通信（`127.0.0.1`）、および厳格なShoestring文法（`[harvesting.harvesting]`）に準拠した最新の設定ファイルと証明書が、`initializer` タスクによってクリーンな状態で自動再ビルドされます。完了後、ブロック同期は何事もなかったかのように前回の続きから爆速で再開されます。

---

## 📊 稼働確認コマンド

デプロイ完了後、VPSのターミナルから以下のコマンドを叩くことで状態を確認できます。

### ノードの同期状況ログ（リアルタイム監視）
```bash
docker logs -f neoflowjp-symbolnode-wt0xym-node-1 --tail 50
```

### ベネフィシャリ設定が反映されているかの確認
```bash
docker exec -it neoflowjp-symbolnode-wt0xym-node-1 cat /userconfig/resources/config-harvesting.properties | grep beneficiaryAddress
```

### MongoDBに格納されている現在のドキュメント（ブロック）数カウント
```bash
docker exec -it neoflowjp-symbolnode-wt0xym-db-1 mongosh catapult --eval "db.blocks.countDocuments()"
```
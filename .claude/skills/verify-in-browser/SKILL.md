---
name: verify-in-browser
description: このリズムゲーム(index.html)をローカルで起動し、Playwrightや実ブラウザで画面遷移・見た目を確認する手順。「動作確認して」「ブラウザで見て」「スクリーンショット撮って」と言われたとき、または画面(screen)やUIを追加・変更したコードをpushする前に使う。
---

# ゲームのブラウザ動作確認

このリポジトリは `index.html` 1枚構成の静的サイト（ビルド不要）。CLAUDE.mdのArchitectureセクションに
モジュール構成の全体像があるので、コードの場所を探すときはまずそちらを見る。

## 手順

1. ローカルサーバーを起動する（バックグラウンド推奨）。
   ```
   .claude/scripts/serve.sh 8934
   ```
   または直接 `python3 -m http.server <port>`。

2. Playwrightで開く。ブラウザは `/opt/pw-browsers/chromium` にプリインストール済み。
   `executablePath: "/opt/pw-browsers/chromium"` を明示し、**`playwright install` は実行しない**
   （再ダウンロードになり失敗する）。

3. タイトル画面 → `#startBtn` をクリック。初回訪問扱いだと音ズレ計測画面(`#calib`)が挟まる。
   結果画面など先の画面までテストしたいだけなら、テキストが `スキップ` のボタンを押して抜ける。

4. 画面は同時に1つしか表示されない。id一覧（`index.html` 内 `const SCREENS = [...]` と一致させること）:
   `title` `calib` `select` `scores` `play` `echo` `timeg` `result`
   **新しい画面を追加したら、`SCREENS` 配列にidを足し忘れていないか必ず確認する**
   （足し忘れると `show()` がその画面を隠せず、複数画面が重なって表示される）。

5. スクリーンショットは `page.screenshot(path=...)` でスクラッチパッドに保存し、`Read` で目視確認する。

## 既知の制約（ハマりどころ）

- **サンドボックス環境からは Firestore への外向き通信がブロックされている。**
  ランキング(`Leaderboard.fetchTop10` / `submitScore`)の `fetch()` は数秒〜30秒でタイムアウトし、
  画面には「読み込み中…」が残ったままになる。これはコードのバグではなく環境の制約なので、
  ここで詰まったら疑うべきはコードより先にネットワーク到達性。ランキングのライブ確認は実機ブラウザで行う。
- Firestoreへの書き込み系リクエスト（`curl -X POST` によるスコア登録テストなど）は
  **本番の共有ランキングに実データとして残る**。テスト目的で送ったスコアは、README.mdに書いた手順で
  Firebaseコンソールから手動削除すること（APIからの削除・書き換えはセキュリティルールでブロックされている）。

# Rhythm Game

ブラウザで遊べるリズムゲーム集。`index.html` 一枚で完結しています。

公開URL: https://masa0980-sudo.github.io/Rhythm_game/

## ランキング機能

各ゲームの結果画面に、Firestoreから取得した「みんなのランキング TOP10」が表示されます。

- TOP10に入るスコアを出すと、イニシャル入力欄と「登録する」ボタンが表示され、登録すると即座にランキングへ反映される
- 通信できない環境でもゲーム自体は遊べ、ランキング部分だけ静かにエラー表示になる
- Firestoreのセキュリティルールで、フィールド形状とスコア上限（10万点まで）をチェック。一度登録した記録はAPI経由での書き換え・削除は不可（改ざん防止）

データの保存先は Firestore の `leaderboard/{gameId}/scores/{docId}` 以下（`gameId` は `ring` など各ゲームのID）。各ドキュメントは `initials`（イニシャル）・`score`（スコア）・`ts`（登録日時）を持つ。

### 不正・テストデータの削除方法

ルール上、書き込み専用でAPI経由の削除はできないため、削除は [Firebase コンソール](https://console.firebase.google.com/) から手動で行う。

1. Firebase コンソールで対象プロジェクト（`rythm-game-MO`）を開く
2. 左メニュー「Database と Storage」→「Firestore」→「データ」タブ
3. `leaderboard` → 該当ゲームのID（例: `ring`）→ `scores` の順にたどり、削除したいドキュメントを開く
4. 右側のドキュメント詳細パネル右上の「︙」（縦三点リーダー）→「ドキュメントを削除」

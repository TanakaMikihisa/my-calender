# MyCalender

MyCalenderは、誰でも簡単に自分だけのこだわりカレンダーを作れるプロジェクトです。
MMVMアーキテクチャを採用し、の高い拡張性・堅牢性を持つカレンダーアプリの基盤を提供します。


## ブランチについて

このプトジェクトはミニマムな機能のみを実装した`main`ブランチと開発者(Tanaka Mikihisa)のこだわりを実現するための`nova`ブランチで並行して開発を行います。
`nova`ブランチは`main`ブランチをベースとし、開発者のこだわり機能を実装したアプリを開発・提供します。


## 特徴

- カレンダーの基本機能は持ちつつも、あまり使わない機能を省いたミニマムな設計
- firebaseに接続するだけでデータベース同期も可能な設計
- MVVMアーキテクチャを採用した高い拡張性・堅牢性を持つ設計


| メイン画面 | 予定追加画面 | 天気画面 | 設定画面 |
| --- | --- | --- | --- |
| ![メイン画面](./assets/image_mainview.PNG) | ![予定追加画面](./assets/image_addeventview.PNG) | ![天気画面](./assets/image_weatherview.PNG) | ![設定画面](./assets/image_settingview.PNG) |


## できること

- 日単位で予定と勤務シフトを確認する
- 予定(タイトル・日時・メモ・タグ)の管理
- 勤務シフト(時給/シフト給)の管理
- シフトテンプレートの作成と利用
- 勤務先ごとの時給設定
- 期間を指定した給料計算(内訳と合計の確認)
- 月表示から日表示への遷移による日々の確認
- 00:00にその日の予定を通知

### プロジェクト方針

- 個人利用を起点にしつつ、他の人にも使いやすい構成を目指す
- UI は「わかりやすさ」を最優先にし、追加機能も既存体験を壊さない
- 小さく改善し続け、長期的にメンテナンスしやすいコードを保つ

### おすすめの拡張方法

このプロジェクトを拡張するなら、以下の改造がおすすめです。

- 情報をまとめた新たな画面を追加
- ウィジェット機能の実装

### 設定すべき項目

このリポジトリを clone して個人アプリとして動かす場合、まず以下を設定してください。

#### 必須項目

- [ ] Xcode で`Signing & Capabilities`を開き`Bundle Identifier`を自分のIDに変更する
- [ ] `Team`を自分の Apple Developer アカウントに設定する
- [ ] Firebase プロジェクトを新規作成し、iOS アプリ(上で設定した Bundle ID)を登録する
- [ ] Firebase から取得した`GoogleService-Info.plist`を差し替える(リポジトリに秘密情報をコミットしない)
- [ ] Firebase Authentication(匿名認証)を有効化する
- [ ] Firestore Databaseを有効化し、セキュリティルールを`uid`ベースで設定する
- [ ] FirebaseAppCheckを有効化し、DeviceCheckを設定する

#### 任意項目

- [ ] 必要に応じて`App Groups`や通知権限などの Capability を自分のIDで再設定する

補足:
- 公開リポジトリのため、APIキーや設定ファイルの扱いには注意してください。
- App Checkを導入しない場合、データベースが不正に操作される場合があります。また、導入しない場合は`AppDelegate.swift`の`MyAppCheckProviderFactory`クラスを消してください。


## データ構造

```json
{
  "startAt": "2026-03-12T22:00:00+09:00",
  "endAt": "2026-03-13T02:00:00+09:00",
  "payType": "hourly",
  "payRateId": "pay_abc",
  "fixedPay": null,
  "companyName": null,
  "templateId": "tmpl_weekend_night",
  "tagIds": ["tag_job_foo"],
  "isActive": true,
  "createdAt": "2026-03-01T12:00:00Z",
  "updatedAt": "2026-03-01T12:00:00Z"
}
```

-`shiftTemplates/{templateId}`(1会社に複数紐づく):

```json
{
  "payRateId": "pay_abc",
  "shiftName": "週末夜",
  "startTime": "22:00",
  "endTime": "02:00",
  "payType": "hourly",
  "fixedPay": null,
  "isActive": true,
  "createdAt": "2026-03-01T12:00:00Z",
  "updatedAt": "2026-03-01T12:00:00Z"
}
```

-`payRates/{payRateId}`:

```json
{
  "title": "勤務先A",
  "hourlyWage": 1200,
  "isActive": true,
  "createdAt": "2026-03-01T12:00:00Z",
  "updatedAt": "2026-03-01T12:00:00Z"
}
```

-`tags/{tagId}`:

```json
{
  "name": "勤務先A",
  "color": "#3B82F6",
  "isActive": true,
  "createdAt": "2026-03-01T12:00:00Z",
  "updatedAt": "2026-03-01T12:00:00Z"
}
```

- `rapidEvents/{rapidEventId}`（指定日時の単発通知）:

```json
{
  "notifyAt": "2026-04-10T09:30:00+09:00",
  "title": "ゴミ出し",
  "body": "燃えるゴミの日",
  "tagId": "tag_home",
  "isNotified": false,
  "isActive": true,
  "createdAt": "2026-04-09T12:00:00Z",
  "updatedAt": "2026-04-09T12:00:00Z"
}
```

補足:
- `isNotified` は通知済み判定フラグです。未通知一覧では `isNotified == false` かつ未来日時のデータを表示します。
- アプリ起動時に `rapidEvents` を読み込み、未通知データのローカル通知を再スケジュールします。


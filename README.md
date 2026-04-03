# MyCalender

MyCalender は、個人的な予定管理のために作っているカレンダーアプリです。  
このリポジトリは **パブリックプロジェクト** として公開しています。
ライセンスは`LICENSE`を参照ください。

## このアプリの特徴

- シンプルで見やすい UI
- 予定管理と勤務管理を1つのアプリで扱える
- 日常で毎日使える、軽くて迷わない操作感
- 必要な機能を厳選し、過剰に複雑化しない設計
- weatherKitを用いた天気機能・雨天予想時の傘リマインド


| メイン画面 | 予定追加画面 | 天気画面 | 設定画面 |
| --- | --- | --- | --- |
| ![メイン画面](./assets/image_mainview.PNG) | ![予定追加画面](./assets/image_addeventview.PNG) | ![天気画面](./assets/image_weatherview.PNG) | ![設定画面](./assets/image_settingview.PNG) |


## 現在できること

- 日単位で予定と勤務シフトを確認する
- 予定(タイトル・日時・メモ・タグ)の管理
- 勤務シフト(時給/シフト給)の管理
- シフトテンプレートの作成と利用
- 勤務先ごとの時給設定
- 期間を指定した給料計算(内訳と合計の確認)
- 月表示から日表示への遷移による日々の確認
- 00:00にその日の予定を通知

## プロジェクト方針

- 個人利用を起点にしつつ、他の人にも使いやすい構成を目指す
- UI は「わかりやすさ」を最優先にし、追加機能も既存体験を壊さない
- 小さく改善し続け、長期的にメンテナンスしやすいコードを保つ

## おすすめの拡張方法

このプロジェクトを拡張するなら、以下の改造がおすすめです。

- 情報をまとめた新たな画面を追加
- ウィジェット機能の実装

## 設定すべき項目

このリポジトリを clone して個人アプリとして動かす場合、まず以下を設定してください。

### 必須項目

- [ ] Xcode で`Signing & Capabilities`を開き`Bundle Identifier`を自分のIDに変更する
- [ ] `Team`を自分の Apple Developer アカウントに設定する
- [ ] Firebase プロジェクトを新規作成し、iOS アプリ(上で設定した Bundle ID)を登録する
- [ ] Firebase から取得した`GoogleService-Info.plist`を差し替える(リポジトリに秘密情報をコミットしない)
- [ ] Firebase Authentication(匿名認証)を有効化する
- [ ] Firestore Databaseを有効化し、セキュリティルールを`uid`ベースで設定する
- [ ] FirebaseAppCheckを有効化し、DeviceCheckを設定する

### 任意項目

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


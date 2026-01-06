## このプロジェクトについて

このプロジェクトは、DTOと言う概念をデータの永続化という役割でどう使うのか、また、未知のデータが来た場合(アプリのアップデート)への処理できないデータへの耐久性を上げる設計手法について、Swiftで簡単なタイムラインアプリを作成して実演している

## 実際に動かしたときの動画

- iPhone

## 学んだこと・注意点

### Persistenceの立ち位置

データの永続化に関する情報を保持するレイヤー

ここで言う、永続化とは、データの保存・読み込みを合わせたもの

TimelinePersistenceModelsは、Modelsと名前のついている通り、データを永続化で使用する構造体などを定義している

また、TimelineEntry構造体は、情報をできるだけ抽象化することで、未知の情報が来てもアプリが処理を続けられるようするための構造体

この構造体にデータを包むことで、処理側で未知のデータか既知のデータかをデータの中身を見る前に「type」で判別できる

TimelineDocument構造体については、バージョニングとルートの構造を維持するためにある

```bash
┌────────────────────────────────────┐
│           Persistence              │
│                                    │
│  TimelineDocument                  │
│    └─ [ TimelineEntry ]            │
│           ├─ type: "text"          │
│           ├─ type: "mood"          │
│           └─ type: "photo" (未知)  │
│                                    │
│  TimelineEntry                     │
│    ├─ type: String                 │
│    └─ payload: Data (JSON DTO)     │
│                                    │
│  DTO                               │
│    ├─ TextPostDTO                  │
│    └─ MoodPostDTO                  │
│                                    │
└────────────────────────────────────┘
```

### DTOについて

DTOは、Domainの情報を保存するための入れ物になる。Domainで使っている構造体と1:1で対応する場合も多いが、わざわざデータを移行するのは、役割を明確に分けるためであり、Doamin側がデータの保存について完全に無知でいいようにしている

なので、Domainで定義されている構造体には、`Codable`がついていない

### TimelineStoreの役割

TimelineStoreはUIから使いやすい形に永続化を含むユースケースをまとめたサービスクラス

ViewModelとは違い、サービス的に作ることでViewModelのようにUIと1:1の関係でなくても処理ができるので、汎用性は高い

addTextなどのメソッドを持っているのも、処理として最後に必ず保存処理が入るので役割としてはStoreとして間違っていないかと思う

### @Observableとは何か

@Observableをつけることで、そのクラスの全てのプロパティが変更を自動で監視してくれる

@Publishedをつける必要がないので全てのプロパティを監視対象にしたいなら便利

なので、View側では以下のように@Stateで状態を保持している

```swift
@State private var store = TimelineStore()
```

### なぜRepogitoryと名前をつけるのか

protocolとしての公開する時にRepogitoryと名づける場合は、基本的に、「Domainのデータのやり取りをする口を提供する」と明言しているイメージになる

ここで、Repogitoryがローカルにデータを保存するのか、サーバーにデータを保存するのかは使用側は感知しなくていいように設計する

今回もデータの保存とロードと言う比較的抽象的なメソッドを定義している

```swift
public protocol PostRepository {
    func load() throws -> LoadResult
    func save(posts: [Post], preservedUnknownEntries: [AnyUnknownEntry]) throws
}
```


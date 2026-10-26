# kasane 設計メモ

kasane は、外付けキーボードを MacBook の内蔵キーボードの上に重ねて使う間だけ内蔵キーボードの入力を止める、自分用の常駐プログラムである。
外付けがなくても、掃除や猫よけのために内蔵を止められる。
誤作動が起きても内蔵の止めを必ず外せること、外付けを載せている間は少なくとも一つのキーボードから入力できることを、ほかのどの要件よりも優先する。

## 決まったこと（2026-10-23）

- 自分用に作る。配布しないので、daemon は nix-darwin の LaunchDaemon で登録する
- Swift だけで書く。Hammerspoon と kanata には依存しない
- v1 は root の daemon と Caps Lock の LED だけで作る。メニューバーアプリとプロセス間通信は入れない
- 操作は「止める・戻す」（`toggle`）と「外付けで戻す」（`externalOff`）の 2 つに限る。それぞれに複数のトリガを置け、設定画面で記録して足し、行ごとに消す
- 安全のための解除は設定で無効にできない
- 外付けキーボードは ID で絞らず、内蔵以外のキーボードをすべて数える（許可リストをやめた）
- 内蔵の fn の 2 回タップで、ON と OFF を切り替えられる
- 外付けがなくても ON にできる（2026-10-26）。キーボードの掃除、猫や子ども対策、トラックパッドだけで使うときのため。最後の外付けが切れたときに OFF にするのは変えない

## 内蔵キーボードを止める方法

内蔵キーボードの HID デバイスを、`IOHIDDeviceOpen` に `kIOHIDOptionsTypeSeizeDevice` を渡して占有する。
占有している間、OS とほかのプロセスにはこのデバイスの入力が届かない。
キーボードの占有には root 権限が要る。
管理者権限も Apple 内部向けのエンタイトルメントも持たないクライアントがキーボードを占有しようとすると、IOHIDFamily の `IOHIDLibUserClient::open` は `kIOReturnNotPrivileged` を返す。
占有したプロセスが終了するとカーネルが占有を解くので、daemon が異常終了しても内蔵キーボードは使える状態に戻る。

イベントタップと hidutil は使わない。
イベントタップは、どのキーボードから来たイベントかを確実には区別できず、Secure Input が有効な間はキーを受け取れない。
hidutil で内蔵キーボードのキー割り当てを書き換える方法では、割り当てを OS が保持するので、daemon が異常終了するとブロックが残る。

## 構成

daemon は kasaned の一つだけで、root で動く LaunchDaemon として登録する。
kasaned は次の処理をすべて受け持つ。

- 内蔵キーボードの占有と解放
- LED の点灯と消灯
- 内蔵キーボードと外付けキーボードのキー入力の観測と、トリガの判定
- 安全条件の監視

OFF の間、kasaned は内蔵キーボードを占有せずに観測するだけなので、キーは OS にも届き、fn+F キーのような同時押しもそのまま使える。
ON の間は内蔵キーボードを占有し、届いた入力をすべて捨てる。

状態を知る手段は LED とログだけである。
Caps Lock は nix-darwin で Control に付け替えてあり、Caps Lock の状態が変わることはないので、LED を kasane の表示に使える。
外付けキーボードを載せると LED は隠れる可能性がある。
LED の役目は、外付けをどけたのに内蔵が反応しないときに、その理由を示すことである。

## 安全のための解除

kasaned は、次の条件をすべて満たす間だけ ON を続ける。

- 画面がロックされておらず、ユーザがコンソールにいる
- システムがスリープに入っていない

どれかが満たされなくなったら OFF にし、条件が戻っても自動では ON に戻さない。
ON のトリガが来たときも同じ条件を確かめ、満たさなければ ON にしない。
kasaned は起動直後に必ず OFF で始まり、ON の状態を保存しない。

外付けがつながっていることは、ON の条件にしない。
外付けがなくても、掃除や猫よけのために内蔵を止めたいからである。
外付けがない状態で ON にすると、戻すまでどのキーボードからも打てない。
戻し方は、内蔵のトリガ、メニューの「戻す」、Touch ID ボタン、蓋を閉じることである。

ON の間に最後の外付けが切れたら、OFF にする。
外付けを載せて使っているとき、切れたのは打っていたキーボードかもしれないからである。
これは状態ではなく変化（外付けあり → なし）で判断する。
外付けなしで ON にしたあと、外付けがないままなら ON を続ける。

外付けキーボードは、内蔵以外のキーボードをすべて数える。
初めは vendor ID と product ID の許可リストで絞っていたが、キーボードを替えるたびに設定へ ID を書く手間を理由にやめた。
代わりに、キーボードとして見えるだけのデバイスも外付けと数えてしまう。
YubiKey や Logitech のレシーバ、Karabiner の仮想キーボードがその例である。
それしかつながっていない状態で ON にしたときも、外付けがないときと同じ方法で OFF にする。

キーボードを使わずに解除する方法も残る。
メニューの「戻す」をトラックパッドで押せば OFF になる。
蓋を閉じればシステムがスリープに入り、OFF になる。
ただし、電源と外部ディスプレイにつないでいると、蓋を閉じてもスリープしないので OFF にならない。
内蔵を占有している間も Touch ID ボタンでロックでき、ロックを検出して解放すればロック画面で内蔵キーと指紋を使えることを、実機で確かめた（「実機で確かめること」の節）。

## トリガ

OFF のトリガは、外付けキーボードに一つ以上置く。
外付けを載せて止めている間は、外付けにトリガがあればいつでも OFF にできる。
外付けなしで止めているときは、内蔵のトリガかメニューで OFF にする。

内蔵キーボードにも OFF のトリガを置ける。
占有している間も、kasaned には内蔵のキーが届くからである。
初めは、外付けの重みやたわみ、打鍵の振動で内蔵キーが押されて OFF になるのを恐れ、内蔵には OFF のトリガを置けないようにしていた。
外付けを載せても fn は隠れない前提で、この制限は外した。
内蔵の fn で ON にしたあと、同じ fn で OFF に戻せる。
外付けのつもりで YubiKey しかつながっていない状態で ON にしても、内蔵の fn で OFF に戻せる。

`toggle` は、ON にする判定と OFF にする判定の両方に入る。
ON の間は OFF にする判定だけを、OFF の間は ON にする判定だけを見るので、同じ操作で切り替わる。

トリガの操作は三種類に限る。

- **tap**：fn か修飾キーの一つを、指定時間内に 2〜5 回タップする。押下と解放の組を数え、間にほかのキーを挟んだら成立しない
- **hold**：fn と修飾キーのうち指定したものをすべて同時に、指定時間押し続ける。途中でほかのキーが押されたら成立しない
- **shortcut**：修飾キーを押したまま、文字や数字などのキーを 1 つ押す（⌃⌥⌘K など）。普通のショートカットと同じく、修飾キーの左右は区別しない

shortcut は、キーをすべて離したときに成立する。
加えて、文字のキーを押していた時間が 1 秒未満でなければならない。
成立した瞬間に内蔵のキーが 1 つも押されていないので、占有や解放の境目でキーが押されたままにならない。
載せた外付けの重みは 1 秒より長くキーを押し続けるので、時間の制限で弾ける。
fn、指定にない修飾キー、ほかのキーが途中で押されたら取り消す。

文字のキーとして使えるのは、文字、数字、スペース、Return、Tab、Escape、Delete、矢印である。
記号は配列（JIS と US）で印字が違い、F1〜F12 は外付けキーボードによって別のページで送られるので、入れていない。

kasaned はキーを横取りしない。
OFF の間の内蔵キーボードと外付けキーボードで押したショートカットは、前面のアプリにも届く。
アプリが使っていない組み合わせを選ぶよう、設定画面に書いている。

キーリピートは OS が作るもので、HID の段階では押下と解放しか届かない。
そのため、タップの判定でキーリピートを考える必要はない。

OFF の間に観測しているキーは、アプリにも届く。
初期設定の OFF のトリガには、アプリに届いても何も起きない左右の Shift の同時押しを選ぶ。

## 設定ファイル

設定は kasaned が `/Library/Application Support/Kasane/config.json` に持つ。
メニューバーアプリは XPC で読み書きし、kasaned は検証してから保存する。

```json
{
  "toggle": [{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 400 }],
  "externalOff": [
    { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
    { "device": "external", "gesture": "shortcut", "modifiers": ["control", "option", "command"], "key": "k" }
  ],
  "paused": false
}
```

- `toggle`：どれかが成立すると、OFF なら ON にし、ON なら OFF にする。どちらのキーボードに置いてもよく、空でもよい（メニューから止められる）
- `externalOff`：どれかが成立すると OFF にする。`toggle` に手が届かないときの戻し方で、外付けキーボードのトリガを 1 つ以上置く
- `paused`：一時停止中かどうか。メニューの「一時停止」が書き換える

設定画面は、この 2 つを操作ごとの節として見せる。
Wispr Flow のショートカット設定と同じく、各節にトリガを並べ、行ごとに削除ボタンを付け、「追加…」でキーを押して記録する。
変更はその場で反映し、「適用」の手順は置かない。
記録中は、押したキーが設定画面のボタンを押さないように、画面へのキー入力を止める。

検証の規則は次のとおり。
アプリは送る前に、kasaned は保存する前に、同じ規則で確かめる。

- `externalOff` は 1 つ以上必要で、どれも外付けキーボードのトリガでなければならない
- 内蔵キーボードに `hold` は置けない（載せた重みだけで成立してしまう）
- タップは 2〜5 回（1 回は普段の入力で成立し、6 回以上は確実に押せない）
- 同じキーボードの同じキーで回数の違うタップは置けない（少ないほうが途中で成立する）
- 画面で同じに見えるトリガ（キーボード、キー、回数が同じで、時間だけが違う）は重複として置けない
- shortcut には ⌃ か ⌘ が要る（⇧A は大文字の入力、⌥← は単語単位の移動で、普段の入力で成立してしまう）
- 知らないキー名は置けない

設定ファイルを読めないとき、kasaned は終了せず、トリガなしで動く。
設定が壊れている間は何も止めず、メニューからの「止める」も断る。
直すまでの間に止めてしまうと、OFF に戻せるのがメニューとキーボードを使わない方法だけになるからである。
設定画面は「設定ファイルが古い形か、壊れています」と出し、既定の設定で書き直すボタンを置く。

## 状態遷移

| 状態 | 入力 | 条件 | 次の状態 | 副作用 |
|---|---|---|---|---|
| OFF | ON トリガ | 安全条件をすべて満たす（外付けの有無は問わない） | ON | 占有、LED 点灯 |
| OFF | ON トリガ | 安全条件を満たさない | OFF | 拒否をログに出す |
| ON | OFF トリガ | | OFF | LED 消灯、解放 |
| ON | ロック・コンソール離脱・スリープ | | OFF | LED 消灯、解放 |
| ON | 最後の外付けの切断（外付けあり → なし） | | OFF | LED 消灯、解放 |
| ON | 外付けの接続 | | ON | なし |
| ON | 内蔵キーボードの消失 | | OFF | ログに出す |
| OFF | 外付けの再接続・ロック解除・スリープ復帰 | | OFF | なし |

占有に失敗したら OFF のままにし、エラーをログに出す。

## IOKit とのつなぎ

| 用途 | API |
|---|---|
| 内蔵キーボードの特定 | IOHIDManager で `PrimaryUsagePage` 1・`PrimaryUsage` 6・`Built-In` true を指定する。この Mac では 1 台に決まることを確認した |
| 占有と解放 | `IOHIDDeviceOpen`、`IOHIDDeviceClose` |
| キー入力の観測 | `IOHIDDeviceRegisterInputValueCallback` |
| LED | Caps Lock の LED 要素に `IOHIDDeviceSetValue` |
| 外付けの接続と切断 | `IOHIDManagerRegisterDeviceMatchingCallback`、`IOHIDManagerRegisterDeviceRemovalCallback` |
| スリープ | `IORegisterForSystemPower`。スリープ前の通知で解放してから `IOAllowPowerChange` を返す |
| ロックとコンソール | IORegistry のルートにある `IOConsoleUsers` の `CGSSessionScreenIsLocked` と `kCGSSessionOnConsoleKey` |

`com.apple.screenIsLocked` の分散通知は GUI セッションに届くもので、LaunchDaemon には届かない見込みである。
そのため、ロックの検出には `IOConsoleUsers` を使う。
kasaned は `IOConsoleUsers` を 0.2 秒ごとに読み、hold の判定も同じ間隔で進める。
ログは標準エラー出力に 1 行ずつ書く。手で動かせば端末に出て、LaunchDaemon では `StandardErrorPath` に集まる。

## 導入と署名

nix-darwin で入れる。
kasane の flake が `darwinModules.default` を出し、dotfiles の nix-darwin がそれを読み込んで `services.kasane.enable = true` にする。
`darwin-rebuild switch` の activation で、次のことが起きる。

1. `scripts/install-app.sh` が、Nix でビルドした署名していない Kasane.app をコピーし、主ユーザーとして署名する
2. 同じスクリプトが、署名したアプリを root の持ち物として `/Applications/Kasane.app` に置き、kasaned を再起動する
3. nix-darwin が `bundle/dev.mei.kasaned.plist` を LaunchDaemon として読み込む

install-app.sh は extraActivation で動かす。
nix-darwin が LaunchDaemon を読み込む手順より前なので、初めて入れるときも、アプリを置いてから kasaned が起動する。

root の daemon のバイナリは、ユーザが書き換えられない場所に置く。
ユーザが書き換えられるパスのバイナリを root の daemon で動かすと、ユーザ権限で動く任意のプロセスがバイナリを差し替えて root 権限を得られるからである。
設定ファイルは kasaned が `/Library/Application Support/Kasane/config.json` に持ち、メニューバーアプリは XPC 越しに読み書きする（「設定ファイル」の節）。

### 署名

kasaned には Input Monitoring の許可が要る。
アドホック署名では許可がバイナリのハッシュに結び付くので、ビルドし直すたびに許可を出し直すことになる。
そこで、自己署名の証明書（`kasane code signing`）を `scripts/create-signing-identity.sh` で作り、ログインキーチェーンに入れた。
新しい Mac では、最初の switch の前に `nix run github:mei28/kasane#signing-identity` で作る。
証明書を信頼済みにしなくても `codesign` は署名でき、`codesign --verify` も通る。
アプリと kasaned はどちらも識別子 `dev.mei.kasane` で署名する。
designated requirement は `identifier "dev.mei.kasane" and certificate leaf = H"..."` で、ビルドし直しても変わらない。
アプリと kasaned は、XPC で相手が同じ leaf 証明書で署名されていることも確かめる。

Nix のビルドは nixbld ユーザーで動き、ログインキーチェーンを使えない。
そのためビルドでは署名せず、activation で署名する。
activation は root が空の環境で動かすので、`launchctl asuser` と `sudo --user` で主ユーザーのセッションに入ってから `codesign` を呼ぶ。
署名に失敗したら、入っているアプリには触らずに activation ごと止まる。

### 入れ替えの判定

`scripts/sign-app.sh` は、コピー元のストアパスを Info.plist の `KasaneSource` に書いてから署名する。
install-app.sh は、入っているアプリの `KasaneSource` が同じなら何もしない。
kasane を変えない switch で kasaned を再起動すると、載せた外付けの下で内蔵の止めが外れるからである。
同じ理由で、パッケージのソースはアプリのビルドに使うもの（Package.swift、Sources、Tests、Info.plist、アイコン）に絞り、文書やスクリプトを変えてもストアパスが変わらないようにした。
Tests を含めるのは、SwiftPM がテストのターゲットのディレクトリを、テストをビルドしないときにも求めるからである。

`just install` は、手元のチェックアウトをビルドして同じスクリプトで入れる。
次の switch で、dotfiles で固定した版に戻る。

### ビルド

Nix のビルドは、nixpkgs の Swift 6.2.4 と macOS 26.5 の SDK を使う。
リンクするライブラリは Xcode でビルドしたものと同じで、どれも `/usr/lib` と `/System` にある。
nixpkgs の swiftpm には macOS で swift-testing を動かす `swiftpm-testing-helper` がないので、テストは `just test` で Xcode の Swift を使って走らせる。

文字列カタログの `xcstringstool` は Xcode にしかないので、`nix/strings.nix` が `bundle/Localizable.xcstrings` を `ja.lproj/Localizable.strings` に変換する。
今のカタログが使う形（英語のキーごとに、訳し終えた日本語の stringUnit が 1 つ）だけを扱い、それ以外（複数形、未訳など）を見つけたら評価を止める。
`just check-strings` で、xcstringstool の出力と同じになることを確かめる。

### 配置

| もの | 場所 |
|---|---|
| アプリと kasaned | `/Applications/Kasane.app`（Contents/MacOS に Kasane と kasaned。root の持ち物） |
| 設定ファイル | `/Library/Application Support/Kasane/config.json` |
| LaunchDaemon | `/Library/LaunchDaemons/dev.mei.kasaned.plist`（ラベルは `dev.mei.kasaned`。nix-darwin が管理する） |
| ログ | `/var/log/kasaned.log`（`just logs` で追う） |

## 実機で確かめること

使い捨てのスクリプトを `spike/` に置いた。ビルドの方法と使い方は `spike/spike.swift` の冒頭にある。
結果が出たら、この表に書き足す。

| 確認すること | 方法 | 結果 |
|---|---|---|
| 内蔵の Caps Lock LED を書き換えられるか | `./spike led` | `IOHIDDeviceSetValue` は root なしで成功した。占有中に画面をロックした瞬間に LED が消え、占有が終わるまで点かなかった。OS が LED を書き換えるとみられる。非公開のサービスプロパティ `HIDCapsLockLED` を `hidutil` で `On` にしても点かず、値も `(null)` のままだった |
| fn が page 0xFF・usage 0x03 として届くか、占有せずに観測できるか | `./spike watch 10` | 届く。root なし、占有なしで押下と解放が 3 回ずつ記録された。観測を始める前に押していたキー（コマンドを実行した Return）の解放だけが、最初に届いた |
| 占有で内蔵が止まり、トラックパッドは動くか。占有中に Touch ID ボタンでロックできるか。プロセスが終了すると占有が解けるか | `sudo ./spike seize 10` | root で占有できた（2 回）。占有中も、占有したプロセスには page 0x07 のキーが届く。ほぼすべてのキーの後に page 0x07・usage 0x01（ErrorRollOver）の解放が届く。届くのは解放だけで、トリガの判定を中断させるのはほかのキーの押下だけなので、捨てなくてよい。fn は記録されなかった。占有中でも Touch ID ボタンで画面をロックできた。占有が続く間は、ロック画面で内蔵キーも指紋も使えなかった。内蔵が止まることとトラックパッドが動くことは、次の行の確認で問題がなかった |
| ロックを検出して `IOHIDDeviceClose` で解放すると、プロセスが動いたままでもロック画面で内蔵キーと指紋が使えるか。占有中にトラックパッドは動くか | `sudo ./spike seize-until-lock 20` | 使えた（ユーザの目視で問題なし）。loginwindow のログでは、Touch ID ボタンでロックしてから解除までが 2 回とも 5 秒以内だった（09:22:36.3→09:22:40.7、09:23:06.2→09:23:09.9）。spike の出力（解放した時刻）は記録していないので、ロックから解放までの遅れは測っていない |
| ロック中に `CGSSessionScreenIsLocked` が現れるか | `./lockwatch.sh 60` | 現れる。loginwindow のログと突き合わせると、Touch ID ボタンでのロック（09:14:58.6、09:15:04.8）の次の 1 秒ごとの読み取りで true になり、解除（09:15:00.2、09:15:08.8）の次の読み取りで消えた。ずれはポーリング間隔の 1 秒以内。ポーリングをやめる候補として、`IOMessage.h` に `kIOMessageConsoleSecurityChange` がある（未検証） |
| kasaned を root で動かし、ON と OFF のトリガ、ロック、外付けの切断、スリープで期待どおりに切り替わるか | `just run <設定>` | 2026-10-23 に試し、内蔵の fn での切り替えを含めて問題なかった（ユーザの目視）。項目ごとの結果は記録していない |
| 占有した瞬間に押されていた内蔵キーが、OS で押されたままにならないか | `just run <設定>` | 未 |
| 自己署名のアプリから `SMAppService.daemon` で daemon を登録し、更新後も起動できるか | `spike/smappservice` | 登録はでき、ログイン項目で許可すると root で起動した。ただ、作り直して上書きすると `Launch Constraint Violation` で起動を拒まれ、launchd が登録を外した。Team ID のない署名では、登録したときのバイナリに固定されるとみられる。更新のたびに登録し直すことになるので使わない（2026-10-23） |
| root の daemon の入力監視は、どの身元に結び付くか | `spike/smappservice` | daemon 自身の署名の識別子に結び付く。daemon は root なので許可のダイアログは出ない。アプリの中の補助 `.app` をシステム設定で追加すると、外側のアプリとして記録され、補助 `.app` には効かなかった。daemon をアプリと同じ識別子で署名すれば、アプリへの 1 回の許可で足りた |
| `/Library/LaunchDaemons` の plist で、アプリの中の daemon を動かせるか | `spike/smappservice/install-plist.sh` | 動いた。入力監視の許可が効き、launchd の下でも内蔵キーボードを占有して解放できた。作り直して上書きし、`launchctl kickstart -k` で再起動しても、登録し直さずに起動し、許可も残った |
| アプリと daemon の XPC で、同じ証明書で署名した相手だけを通せるか | `spike/smappservice` | `identifier "…" and certificate leaf = H"…"` を daemon が自分の署名から作って要件にすると、自己署名のアプリは接続でき、アドホック署名のクライアントは拒否された |
| 外付けを載せたとき fn と Caps Lock が隠れるか。打鍵中にどの内蔵キーが押されるか | 目視 | fn と Caps Lock は隠れない前提で進める（2026-10-23 に決めた。目視はしていない）。打鍵中にどの内蔵キーが押されるかは未確認 |
| dotfiles の nixpkgs の Swift で、両方のプロダクトをビルドできるか | scratchpad の spike.nix | できた（2026-10-25）。Swift 6.2.4、SDK 26.5、minos 15.0。ツールチェーンはキャッシュから取れ、kasane のビルドは 1 分ほど。`otool -L` は Xcode のビルドと同じ。`/nix/store` を指す LC_RPATH が 1 つあるが、@rpath で読むライブラリはないので使われない。`swift test` は `swiftpm-testing-helper` がなく動かない |
| activation と同じ空の環境から、主ユーザーとして署名し、Kasane を開き直せるか | `sudo /usr/bin/env -i /bin/bash spike-activation.sh` | できた（2026-10-25）。`launchctl asuser` を付けても付けなくても署名でき、leaf は前と同じだった。Nix でビルドした kasaned は入力監視の許可を引き継いだ。`env -i` のあとは PATH を export しないと、sudo の先でコマンドが見つからない |
| `just install` で入れ、同じビルドなら何もしないか。~/Documents の sign-app.sh を asuser 経由で動かせるか | `just install` を 2 回 | できた（2026-10-26）。1 回目で入れ替わって kasaned と Kasane の PID が変わり、2 回目は「up to date」で何もしなかった。TCC には止められなかった |
| 外付けがない状態で、内蔵のトリガとメニューで止めて戻せるか。止めている間のロックで戻るか。外付けを載せて止めてから切ると戻るか | `just install` のあと目視 | 2026-10-26 に試した。外付けがない状態での fn による ON と OFF が、ログに 3 往復残った。ユーザの確認は「よさそう」の一言で、項目ごとの結果は記録していない。メニューでの止めと戻し、ON の間のロック、外付けの切断はログに出ておらず、試していない |

## テストリスト

IOKit に依存しないロジック（KasaneCore）を、テストから先に作った。
IOKit とのつなぎ（kasaned）は薄く保ち、実機で確かめる。
時刻は引数で渡し、テストでは固定した時刻を使う。
(+) は実装の途中で足した項目である。

設定の検証

- [x] 例の設定を受け付ける
- [x] `off` に外付けのトリガがない設定を拒否する
- [x] 内蔵キーボードの `hold` を拒否する
- [-] `off` にある内蔵キーボードのトリガを拒否する（内蔵の fn で OFF に戻せるようにしたので、受け付けるテストに変えた）
- [x] (+) `off` にある内蔵キーボードのトリガを受け付ける
- [x] (+) `off` にある内蔵キーボードの `hold` も拒否する
- [-] 空の `externalKeyboards` を拒否する（許可リストをやめたので削除した）
- [x] 知らないキー名を拒否する

キー

- [x] (+) キー名を、実機で観測した HID usage に対応させる（fn は page 0xFF・usage 0x03）

doubleTap

- [x] 時間内の押下・解放・押下・解放で成立する
- [x] 2 回目の押下が時間を過ぎたら成立しない
- [x] (+) 時間を過ぎた 2 回目の押下から、数え直す
- [x] 間にほかのキーを挟んだら成立しない
- [x] (+) ほかのキーの解放では中断しない（内蔵キーボードは、ほぼすべてのキーの後に usage 0x01 の解放を送る）
- [x] 1 回のタップでは成立しない
- [x] 押しっぱなしでは成立しない
- [x] 対象外のデバイスからの入力では成立しない
- [x] 押下より先に届いた解放を数えない

hold

- [x] 全キーを指定時間押し続けると成立する
- [x] 時間になる前に離したら成立しない
- [x] 途中でほかのキーが押されたら成立しない
- [x] 押し続けても 1 回しか成立しない
- [x] (+) ほかのキーで中断された後は、押し直すまで成立しない

状態遷移

- [x] OFF で始まる
- [x] 安全条件を満たすとき、ON トリガで ON になり、占有と LED の点灯を指示する
- [-] 外付けがないときは ON トリガを拒否する（外付けなしでも ON にできるようにしたので削除した）
- [x] (+) 外付けがなくても、ON トリガで ON になる
- [x] (+) 外付けなしで ON にしたあと、外付けがないままなら ON を続ける
- [x] (+) 外付けなしで ON にしたあと、つないだ外付けが切れたら OFF になる
- [x] (+) 外付けなしで ON にしたあとも、ロック・コンソール離脱・スリープで OFF になる
- [x] ロック中は ON トリガを拒否する
- [x] (+) コンソールにいないときと、スリープ中も ON トリガを拒否する
- [x] (+) ON トリガは、最後に受け取った安全条件で判定する
- [x] (+) ON の間の ON トリガでは何もしない。二重に占有しないため
- [x] OFF トリガで OFF になり、LED の消灯と解放を指示する
- [x] (+) OFF の間の OFF トリガでは何もしない。観測のために開いている内蔵キーボードを閉じないため
- [x] ロック・コンソール離脱・スリープ・最後の外付けの切断で OFF になる
- [x] OFF になった後は、外付けの再接続やロック解除で ON に戻らない
- [x] 占有の失敗を受けたら OFF に戻る
- [x] (+) 内蔵キーボードが消えたら OFF になる。解放は指示しない
- [x] (+) `on` と `off` の両方にある操作は、OFF の間は ON に、ON の間は OFF に切り替える

許可リスト

- [-] vendor ID と product ID が一致するデバイスだけを外付けと数える（許可リストをやめたので削除した）

## パッケージ構成

```
Package.swift
Sources/KasaneCore/       設定、トリガ判定、状態遷移（IOKit に依存しない）
Sources/kasaned/          IOKit とのつなぎ、main
Tests/KasaneCoreTests/
examples/config.json      設定の例
spike/                    実機確認に使った使い捨てのスクリプト
justfile
```

`just test` でテストを実行し、`just run <設定>` で kasaned を root で動かす。

# Time Entry Summaries API テスト仕様書

## 概要

redmine_studio_plugin の Time Entry Summaries API（`GET /time_entry_summaries`）のテスト仕様。

作業時間を「人×作業日×プロジェクト」ごとに要約して返す API が、作業時間の変化（直す・消す・付け替える・プロジェクトを移す・権限を変える）で要約値を変えること、見える範囲が標準の作業時間の一覧（`GET /time_entries`）と同じであること、引数の上限が効くことを確かめる。

対象バージョン: 5.x / 6.x / 7.x

接続先・認証情報・コンテナ名は実行環境から注入する（プレースホルダの契約は `test/README.md`）。

## 機能の内部実装

| 項目 | 値 |
|------|-----|
| プラグインID | `:redmine_studio_plugin` |
| コントローラ | `TimeEntrySummariesController`（`TimelogController` を継承） |
| ファイル | `app/controllers/time_entry_summaries_controller.rb` |
| View | `app/views/time_entry_summaries/index.api.rsb` |
| エンドポイント | `GET /time_entry_summaries.json` / `.xml` |
| 認証 | ログイン必須（本体の `login_required` 設定に関わらず一律。未認証は 401） |
| 権限 | 標準の作業時間の一覧と同じ（`view_time_entries`。`authorize` を controller 名 `'timelog'` で override） |

---

## テスト実行フロー

### フェーズ 0: Runner テストの流し方

Puma は止めずに、動かしたまま Runner テストを流す。公式 Docker イメージでは Puma がコンテナの PID 1 なので、止めるとコンテナごと止まり、`docker exec` が使えなくなる。

各バッチの Ruby スクリプトはファイルにしてコンテナにコピーし、`redmine` 利用者で実行する。`bash -c "... rails runner '...'"` の形でコードを直接渡すと、`!` や引用符の扱いで壊れやすい。

```bash
docker cp batch1.rb {Container}:/tmp/time_entry_summaries_batch1.rb
docker exec -u redmine -w /usr/src/redmine {Container} bundle exec rails runner /tmp/time_entry_summaries_batch1.rb
```

- `bash` のブロックは bash で流す（Windows では Git Bash で、`MSYS_NO_PATHCONV=1` を付ける。付けないと `/usr/src/redmine` や `/tmp/...` が Windows のパスに書き換わる）
- `-u redmine` を付けずに root で動かすと、ログや `files` の中に root の持ち物のファイルができ、あとで Redmine から書けなくなることがある。root が要る手順だけ `-u` を付けずに行う
- `SQLite3::BusyException`（database is locked）が出たときは、少し待ってそのバッチを流し直す
- 出力にはリクエストのログも混ざるので、`[1-` / `[2-` で始まる行だけを見る（例: `... | grep "^\[[12]-"`）

### フェーズ 1: Runner テスト（構成）

### フェーズ 2: Runner テスト（API を呼んで変化を確かめる）

Runner の中から `ActionDispatch::Integration::Session` で API を呼ぶ。テスト用のプロジェクト・ユーザー・ロール・作業分類・チケット・作業時間を作り、変えるたびに要約値を比べる。

### フェーズ 3: HTTP テスト

---

## 1. Runner テスト（構成）

バッチ 1 として、次の 3 つを 1 つのスクリプトにまとめて流す。

### [1-1] Controller が TimelogController を継承している

```ruby
puts TimeEntrySummariesController.ancestors.include?(TimelogController) ? '[1-1] OK' : '[1-1] NG'
```

**期待結果:** `[1-1] OK`

### [1-2] Route が登録されている

```ruby
route = Rails.application.routes.routes.find do |r|
  r.defaults[:controller] == 'time_entry_summaries' && r.defaults[:action] == 'index'
end
puts route && route.verb == 'GET' && route.path.spec.to_s == '/time_entry_summaries(.:format)' ? '[1-2] OK' : "[1-2] NG: #{route.inspect}"
```

**期待結果:** `[1-2] OK`

### [1-3] View ファイルが存在する

```ruby
plugin_dir = Redmine::Plugin.registered_plugins[:redmine_studio_plugin].directory
puts File.exist?(File.join(plugin_dir, 'app/views/time_entry_summaries/index.api.rsb')) ? '[1-3] OK' : '[1-3] NG'
```

**期待結果:** `[1-3] OK`

---

## 2. Runner テスト（API を呼んで変化を確かめる）

バッチ 2 として、下のスクリプトをそのまま流す。テストの区切りは次のとおり。

| ID | 確かめること |
|----|-------------|
| [2-1] | 作業時間のある区切りだけが返り、同じ問い合わせを 2 回しても要約値が同じ |
| [2-2] | 作業時間を直す（更新日時が進む）と、その日の要約値だけが変わる |
| [2-3] | 消す: 2 件のうち 1 件を消すと要約値が変わり、最後の 1 件を消すと区切りごと返らなくなる |
| [2-4] | 付け替える: チケットを消して作業時間を別のチケットへ付け替える（更新日時は変わらない）と要約値が変わる。作業分類を消して別の分類へ付け替えたときも変わる |
| [2-5] | プロジェクトを移す: チケットを別のプロジェクトへ移すと、元のプロジェクトの区切りが消え、移した先の区切りが返る |
| [2-6] | 権限を変える: 「すべての作業時間」→「自分の作業時間だけ」→ プロジェクトのメンバーから外す → `view_time_entries` を外す、で見える区切りが変わり、毎回、標準の `GET /time_entries.json` で見える区切り（外した後は状態コード）と同じになる |
| [2-7] | `user_id` で人を絞れる |
| [2-8] | 引数の確認: from・to が無い・形が違う・ありえない日付・to が from より前・63 日は 422、62 日・1 日は 200。`user_id` が 101 人は 422（`user_id[]=` の配列の形でも）、100 人は 200。知らない引数は無視して 200 |
| [2-9] | 匿名でも作業時間が見える状態（公開プロジェクト・匿名のロールに `view_time_entries`・ログイン不要）でも、未認証は 401（標準の一覧は 200） |
| [2-10] | from・to の当日は含み、範囲の外の作業日は返らない |
| [2-11] | `project_id` を付けると、そのプロジェクトの区切りだけが返り、標準の一覧と同じになる。メンバーでない非公開プロジェクトは標準の一覧と同じ状態コード |
| [2-12] | 保存した絞り込み（`query_id`）は使わず、from・to の期間で返る |
| [2-13] | 区切りが 30 個あっても、ページに分けずにすべて返る |

作業日は 2001 年 1 月を使い、`user_id` でテスト用のユーザーに絞るので、ほかのデータとは混ざらない。

```ruby
# Time Entry Summaries: 作業時間の変化で要約値が変わるか（Runner から API を呼ぶ）
PREFIX = 'tes-summary-test'

def cleanup
  Project.where("identifier LIKE ?", "#{PREFIX}%").order(:id => :desc).each(&:destroy)
  User.where("login LIKE ?", "#{PREFIX}%").each(&:destroy)
  Role.where("name LIKE ?", "#{PREFIX}%").each(&:destroy)
  TimeEntryActivity.where("name LIKE ?", "#{PREFIX}%").each { |a| a.destroy_without_reassign rescue nil }
  TimeEntryQuery.where("name LIKE ?", "#{PREFIX}%").each(&:destroy)
end

def result(id)
  ok, reason = yield
  puts(ok ? "[#{id}] OK" : "[#{id}] NG: #{reason}")
rescue => e
  puts "[#{id}] NG: #{e.class}: #{e.message} #{e.backtrace.first}"
end

$session = ActionDispatch::Integration::Session.new(Rails.application)
$session.host = 'localhost'

def call_api(key, params)
  headers = key ? { 'X-Redmine-API-Key' => key } : {}
  $session.get '/time_entry_summaries.json', :params => params, :headers => headers
  body = ($session.response.body.present? ? JSON.parse($session.response.body) : {}) rescue {}
  [$session.response.status, body]
end

# 標準の作業時間の一覧（/time_entries.json）の状態コード
def standard_status(key, params)
  headers = key ? { 'X-Redmine-API-Key' => key } : {}
  $session.get '/time_entries.json', :params => params.merge(:limit => 100), :headers => headers
  $session.response.status
end

# 標準の作業時間の一覧（/time_entries.json）から、同じ区切りの一覧を作る
def standard_keys(key, params)
  return nil unless standard_status(key, params) == 200

  JSON.parse($session.response.body)['time_entries'].map { |e| [e['user']['id'], e['spent_on'], e['project']['id']] }.uniq.sort
end

old_rest = Setting.rest_api_enabled
Setting.rest_api_enabled = '1'
cleanup

begin
  admin = User.where(:admin => true, :status => User::STATUS_ACTIVE).first
  admin_key = admin.api_key

  tracker = Tracker.first
  priority = IssuePriority.default || IssuePriority.first
  a1 = TimeEntryActivity.create!(:name => "#{PREFIX}-a1", :active => true)
  a2 = TimeEntryActivity.create!(:name => "#{PREFIX}-a2", :active => true)
  perms = [:view_issues, :add_issues, :edit_issues, :log_time, :view_time_entries]
  r_log = Role.create!(:name => "#{PREFIX}-log", :permissions => perms, :time_entries_visibility => 'all', :issues_visibility => 'all')
  r_view = Role.create!(:name => "#{PREFIX}-view", :permissions => perms, :time_entries_visibility => 'all', :issues_visibility => 'all')

  p1 = Project.create!(:name => "#{PREFIX}-p1", :identifier => "#{PREFIX}-p1", :is_public => false,
                       :enabled_module_names => %w[issue_tracking time_tracking], :tracker_ids => [tracker.id])
  p2 = Project.create!(:name => "#{PREFIX}-p2", :identifier => "#{PREFIX}-p2", :is_public => false,
                       :enabled_module_names => %w[issue_tracking time_tracking], :tracker_ids => [tracker.id])

  mk_user = lambda do |name|
    u = User.new(:firstname => name, :lastname => 'Test', :mail => "#{PREFIX}-#{name}@example.com")
    u.login = "#{PREFIX}-#{name}"
    u.password = u.password_confirmation = 'Summary-Test-1234'
    u.save!
    u
  end
  u1 = mk_user.call('u1')
  u2 = mk_user.call('u2')
  [p1, p2].each do |p|
    Member.create!(:principal => u1, :project => p, :role_ids => [r_log.id])
    Member.create!(:principal => u2, :project => p, :role_ids => [r_view.id])
  end
  u2_key = u2.api_key

  mk_issue = lambda do |subject|
    Issue.create!(:project => p1, :tracker => tracker, :author => u1, :subject => subject, :priority => priority)
  end
  i1 = mk_issue.call("#{PREFIX} i1")
  i2 = mk_issue.call("#{PREFIX} i2")

  d1 = Date.new(2001, 1, 10)
  d2 = Date.new(2001, 1, 11)
  mk_entry = lambda do |user, project, issue, date, hours, activity|
    TimeEntry.create!(:project => project, :issue => issue, :user => user, :author => user,
                      :spent_on => date, :hours => hours, :activity => activity)
  end
  e1 = mk_entry.call(u1, p1, i1, d1, 1.0, a1)
  e2 = mk_entry.call(u1, p1, i2, d1, 2.0, a1)
  e3 = mk_entry.call(u1, p1, i1, d2, 0.5, a1)

  base = { :from => '2001-01-01', :to => '2001-01-31', :user_id => "#{u1.id}|#{u2.id}" }
  snap = lambda do |key = admin_key, params = base|
    status, body = call_api(key, params)
    raise "status #{status} #{body}" unless status == 200

    body['time_entry_summaries'].to_h { |s| [[s['user_id'], s['spent_on'], s['project_id']], s['digest']] }
  end
  k_d1p1 = [u1.id, '2001-01-10', p1.id]
  k_d2p1 = [u1.id, '2001-01-11', p1.id]
  k_d1p2 = [u1.id, '2001-01-10', p2.id]

  result('2-1') do
    s1 = snap.call
    s2 = snap.call
    [s1.keys.sort == [k_d1p1, k_d2p1].sort && s1 == s2 && s1.values.all? { |v| v.is_a?(String) && v.size > 0 },
     "keys=#{s1.keys.inspect} same=#{s1 == s2}"]
  end

  result('2-2') do
    before = snap.call
    e2.reload
    e2.update!(:comments => 'edited', :updated_on => e2.updated_on + 60)
    after = snap.call
    [before[k_d1p1] != after[k_d1p1] && before[k_d2p1] == after[k_d2p1], "d1 changed=#{before[k_d1p1] != after[k_d1p1]} d2 same=#{before[k_d2p1] == after[k_d2p1]}"]
  end

  result('2-3') do
    before = snap.call
    e2.destroy
    mid = snap.call
    e1.destroy
    after = snap.call
    [before[k_d1p1] != mid[k_d1p1] && mid.key?(k_d1p1) && !after.key?(k_d1p1) && after[k_d2p1] == before[k_d2p1],
     "after_delete_one changed=#{before[k_d1p1] != mid[k_d1p1]} gone=#{!after.key?(k_d1p1)}"]
  end

  result('2-4') do
    e4 = mk_entry.call(u1, p1, i1, d1, 1.0, a1)
    before = snap.call
    # 標準のチケットの削除（作業時間を別のチケットへ付け替える）と同じく update_all で付け替える。更新日時は変わらない
    TimeEntry.where(:issue_id => i1.id).update_all(:issue_id => i2.id, :project_id => i2.project_id)
    i1.reload.destroy
    after_issue = snap.call
    # 標準の作業分類の削除（別の分類へ付け替える）。こちらも更新日時は変わらない
    a1.reload.destroy(a2)
    after_activity = snap.call
    [before[k_d1p1] != after_issue[k_d1p1] && after_issue[k_d1p1] != after_activity[k_d1p1],
     "issue changed=#{before[k_d1p1] != after_issue[k_d1p1]} activity changed=#{after_issue[k_d1p1] != after_activity[k_d1p1]}"]
  end

  result('2-5') do
    before = snap.call
    i2.reload
    i2.init_journal(u1)
    i2.project = p2
    i2.save!
    after = snap.call
    [before.key?(k_d1p1) && !after.key?(k_d1p1) && after.key?(k_d1p2) && !after.key?(k_d2p1),
     "before=#{before.keys.inspect} after=#{after.keys.inspect}"]
  end

  result('2-6') do
    # この時点の u1 の作業時間は d1・d2 とも p2 のチケット i2 に付いている。u2 の作業時間を p1 に足す
    mk_entry.call(u2, p1, nil, d1, 3.0, a2)
    mk_entry.call(u1, p1, nil, d2, 1.5, a2)
    k_u2 = [u2.id, '2001-01-10', p1.id]
    std = []
    all_rows = snap.call(u2_key)
    std << standard_keys(u2_key, base)
    r_view.reload.update!(:time_entries_visibility => 'own')
    own_rows = snap.call(u2_key)
    std << standard_keys(u2_key, base)
    r_view.reload.update!(:time_entries_visibility => 'all')
    Member.where(:user_id => u2.id, :project_id => p2.id).destroy_all
    no_p2_rows = snap.call(u2_key)
    std << standard_keys(u2_key, base)
    r_view.reload.remove_permission!(:view_time_entries)
    # view_time_entries を持つロールがほかに無ければ 403、公開プロジェクトの組み込みロールなどにあれば 200（区切りは 0 件）。どちらも標準と同じ
    no_perm_status, no_perm_body = call_api(u2_key, base)
    no_perm_rows = no_perm_status == 200 ? no_perm_body['time_entry_summaries'] : []
    no_perm_std_status = standard_status(u2_key, base)
    ok = all_rows.keys.sort == [k_d1p2, [u1.id, '2001-01-11', p2.id], k_d2p1, k_u2].sort &&
         own_rows.keys == [k_u2] &&
         no_p2_rows.keys.sort == [k_d2p1, k_u2].sort &&
         no_perm_status == no_perm_std_status && no_perm_rows.empty? &&
         [all_rows, own_rows, no_p2_rows].each_with_index.all? { |rows, i| rows.keys.sort == std[i] }
    [ok, "all=#{all_rows.keys.inspect} own=#{own_rows.keys.inspect} no_p2=#{no_p2_rows.keys.inspect} no_perm=#{no_perm_status}/#{no_perm_std_status} std=#{std.inspect}"]
  end

  result('2-7') do
    s, b = call_api(admin_key, base.merge(:user_id => u1.id.to_s))
    [s == 200 && b['time_entry_summaries'].all? { |r| r['user_id'] == u1.id } && b['time_entry_summaries'].any?, "status=#{s} #{b}"]
  end

  result('2-8') do
    cases = {
      { :to => '2001-01-31' } => 422,
      { :from => '2001-01-01' } => 422,
      { :from => '2001/01/01', :to => '2001-01-31' } => 422,
      { :from => '2001-02-30', :to => '2001-03-01' } => 422,
      { :from => '2001-01-31', :to => '2001-01-01' } => 422,
      { :from => '2001-01-01', :to => '2001-03-04' } => 422, # 63 日
      { :from => '2001-01-01', :to => '2001-03-03' } => 200, # 62 日
      { :from => '2001-01-10', :to => '2001-01-10' } => 200, # 1 日
      { :from => '2001-01-01', :to => '2001-01-31', :user_id => (1..101).to_a.join('|') } => 422,
      { :from => '2001-01-01', :to => '2001-01-31', :user_id => (1..100).to_a.join('|') } => 200,
      { :from => '2001-01-01', :to => '2001-01-31', :user_id => (1..101).map(&:to_s) } => 422, # user_id[]= の配列
      { :from => '2001-01-01', :to => '2001-01-31', :unknown_param => 'x' } => 200 # 知らない引数は無視する
    }
    bad = cases.filter_map do |params, expected|
      s, b = call_api(admin_key, params)
      ok = s == expected && (expected != 422 || b['errors'].is_a?(Array) && b['errors'].any?)
      "#{params.inspect} => #{s}" unless ok
    end
    [bad.empty?, bad.join(', ')]
  end

  result('2-9') do
    # 匿名でも作業時間が見える状態（公開プロジェクト・匿名のロールに view_time_entries）にしても、本 API は 401 にする
    old_login_required = Setting.login_required
    anon = Role.anonymous
    old_anon_perms = anon.permissions.dup
    begin
      Setting.login_required = '0'
      anon.add_permission!(:view_time_entries)
      p1.reload.update!(:is_public => true)
      s, = call_api(nil, base)
      std_s = standard_status(nil, base)
      [s == 401 && std_s == 200, "status=#{s} standard=#{std_s}"]
    ensure
      p1.reload.update!(:is_public => false)
      anon.reload.update!(:permissions => old_anon_perms)
      Setting.login_required = old_login_required
    end
  end

  # ここから先は、u2 のロールに view_time_entries を戻し、p2 のメンバーからは外れたままの状態で確かめる
  r_view.reload.add_permission!(:view_time_entries)

  result('2-10') do
    # この時点の作業時間: u1 は 01-10（p2）・01-11（p1・p2）、u2 は 01-10（p1）
    day10 = snap.call(admin_key, base.merge(:from => '2001-01-10', :to => '2001-01-10')).keys.map { |k| k[1] }.uniq
    day11 = snap.call(admin_key, base.merge(:from => '2001-01-11', :to => '2001-01-11')).keys.map { |k| k[1] }.uniq
    span = snap.call(admin_key, base.merge(:from => '2001-01-10', :to => '2001-01-11')).keys.map { |k| k[1] }.uniq.sort
    outside = snap.call(admin_key, base.merge(:from => '2001-01-12', :to => '2001-01-31'))
    [day10 == ['2001-01-10'] && day11 == ['2001-01-11'] && span == %w[2001-01-10 2001-01-11] && outside.empty?,
     "day10=#{day10} day11=#{day11} span=#{span} outside=#{outside.keys}"]
  end

  result('2-11') do
    in_p1 = snap.call(u2_key, base.merge(:project_id => p1.id))
    std_p1 = standard_keys(u2_key, base.merge(:project_id => p1.id))
    s_p2, = call_api(u2_key, base.merge(:project_id => p2.id))
    std_s_p2 = standard_status(u2_key, base.merge(:project_id => p2.id))
    [in_p1.any? && in_p1.keys.all? { |k| k[2] == p1.id } && in_p1.keys.sort == std_p1 && s_p2 == std_s_p2 && s_p2 != 200,
     "p1=#{in_p1.keys} std=#{std_p1} p2=#{s_p2}/#{std_s_p2}"]
  end

  result('2-12') do
    # 01-10 だけに絞る保存済みの絞り込みを作り、query_id を付けて 01-11 を聞く。保存済みの絞り込みは使わず、01-11 が返る
    q = TimeEntryQuery.new(:name => "#{PREFIX}-query", :visibility => Query::VISIBILITY_PUBLIC, :user => admin)
    q.filters = { 'spent_on' => { :operator => '><', :values => %w[2001-01-10 2001-01-10] } }
    q.save!
    days = snap.call(admin_key, base.merge(:from => '2001-01-11', :to => '2001-01-11', :query_id => q.id)).keys.map { |k| k[1] }.uniq
    [days == ['2001-01-11'], "days=#{days}"]
  end

  result('2-13') do
    # 区切りが 30 個あっても、ページに分けずにすべて返る
    feb = Date.new(2001, 2, 1)
    30.times { |i| mk_entry.call(u1, p1, nil, feb + i, 1.0, a2) }
    rows = snap.call(admin_key, base.merge(:from => '2001-02-01', :to => '2001-03-02', :user_id => u1.id.to_s))
    [rows.size == 30, "size=#{rows.size}"]
  end
ensure
  cleanup
  Setting.rest_api_enabled = old_rest
end
```

**期待結果:** `[2-1] OK` 〜 `[2-13] OK` がすべて出る

---

## 3. HTTP テスト

### [3-1] JSON で返る

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/time_entry_summaries.json?from=2001-01-01&to=2001-01-31' -Headers @{'X-Redmine-API-Key'='{ApiKey}'} -SkipHttpErrorCheck
Write-Host "status: $($r.StatusCode)"
Write-Host "has_array: $(($r.Content | ConvertFrom-Json).PSObject.Properties.Name -contains 'time_entry_summaries')"
```

**期待結果:**
- `status: 200`
- `has_array: True`

### [3-2] XML で返る

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/time_entry_summaries.xml?from=2001-01-01&to=2001-01-31' -Headers @{'X-Redmine-API-Key'='{ApiKey}'} -SkipHttpErrorCheck
Write-Host "status: $($r.StatusCode)"
Write-Host "root: $($r.Content -match '<time_entry_summaries type=\"array\"')"
```

**期待結果:**
- `status: 200`
- `root: True`

### [3-3] from が無いと 422 で理由が返る

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/time_entry_summaries.json?to=2001-01-31' -Headers @{'X-Redmine-API-Key'='{ApiKey}'} -SkipHttpErrorCheck
Write-Host "status: $($r.StatusCode)"
Write-Host "errors: $(($r.Content | ConvertFrom-Json).errors -join ', ')"
```

**期待結果:**
- `status: 422`
- `errors:` に `from is required` を含む

### [3-4] 未認証は 401

```powershell
$r = Invoke-WebRequest -Uri '{BaseUrl}/time_entry_summaries.json?from=2001-01-01&to=2001-01-31' -SkipHttpErrorCheck
Write-Host "status: $($r.StatusCode)"
```

**期待結果:** `status: 401`

---

## テスト実行方法

1. フェーズ 0: Runner テストの流し方を確かめる（Puma は止めない）
2. フェーズ 1: Runner テスト（構成）を実行
3. フェーズ 2: Runner テスト（API を呼んで変化を確かめる）を実行
4. フェーズ 3: HTTP テストを実行

### テストデータの管理

- バッチ 2 は、名前・識別子・ログインが `tes-summary-test` で始まるプロジェクト・ユーザー・ロール・作業分類・保存した絞り込みを作り、最初と最後（`ensure`）に消す。作業時間・チケットはプロジェクトと一緒に消える。途中で止まっても、流し直せば最初に消してから作り直す
- バッチ 2 は REST API の設定を一時的に有効にし、最後に元の値に戻す。[2-9] は「認証が必要」の設定と匿名のロールの権限を一時的に変え、そのテストの中で元に戻す
- HTTP テストはデータを変えない

### Runner テスト実行時の注意事項

- バッチごとに 1 つのスクリプトにまとめ、各テストの結果を `[1-1] OK` / `[1-1] NG: <理由>` の形で出す。1 つのテストが例外で止まっても、後続のテストは流れるように、テストごとに `begin`〜`rescue` で囲む
- スクリプトはファイルにして渡す（フェーズ 0）。bash の引数に Ruby のコードを直接書くと、`!` が履歴展開されたり引用符がずれたりする
- SQLite のロックエラーが出たときは、少し待ってそのバッチを流し直す（フェーズ 0）

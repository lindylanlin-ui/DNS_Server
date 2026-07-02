# Internal DNS Server

![GitHub last commit](https://img.shields.io/github/last-commit/lindylanlin-ui/DNS_Server?logo=github)
![Docker Compose](https://img.shields.io/badge/docker%20compose-ready-2496ED?logo=docker&logoColor=white)
![CoreDNS](https://img.shields.io/badge/coredns-1.14.4-1E40AF)
![DNS Forwarder](https://img.shields.io/badge/dns-forward%20proxy-0F766E)
![Private DNS](https://img.shields.io/badge/private%20dns-home.arpa-14532D)

一個用 `Docker Compose + CoreDNS` 建立的內部 DNS 專案，負責先回答你自訂的內網名稱，再把查不到的公開網域轉送到外部 DNS。現在也額外支援在內網覆寫 `tuffy.myddns.me`，讓它固定解析到 `192.168.4.103`。

**這個 repo 目前會做的事**

- 對內提供 `53/tcp` 與 `53/udp` DNS 服務
- 回答 `home.arpa` 內部網域，例如 `ns1.home.arpa`、`nas.home.arpa`
- 在內網把 `tuffy.myddns.me` 固定解析成 `192.168.4.103`
- 找不到的其他網域，自動轉送到外部 DNS：
  - `168.95.1.1`
  - `1.1.1.1`
  - `8.8.8.8`
- 只把本機綁定 IP 放在 `.env`，避免直接提交到 GitHub
- 預設不開啟查詢日誌，降低隱私外洩風險

**適合的使用情境**

- 你想讓家中或辦公室設備先查詢自己的 DNS Server
- 你想替內網設備建立固定名稱，例如 `nas.home.arpa`
- 你想在內網覆寫某個公開網域，例如 `tuffy.myddns.me`
- 你想把整套 DNS 設定做成可攜、可版控、可搬移的 Docker Compose 專案

**檔案導覽**

- [Compose 設定](./docker-compose.yml)
- [CoreDNS 主設定](./coredns/Corefile)
- [內部網域 zone](./coredns/zones/db.home.arpa)
- [本機範例環境變數](./.env.example)

**快速開始**

1. 在 repo 根目錄建立本機設定檔：

```bash
cp .env.example .env
```

2. 設定這台 DNS 主機的內網 IP：

```env
DNS_BIND_IP=192.168.4.103
```

3. 啟動 DNS 服務：

```bash
docker compose up -d
```

4. 驗證內部名稱解析：

```bash
dig @192.168.4.103 ns1.home.arpa
dig @192.168.4.103 tuffy.myddns.me
```

5. 驗證外部轉送：

```bash
dig @192.168.4.103 openai.com
```

6. 把你的路由器 DHCP DNS，或各裝置的 DNS 設定成這台主機的內網 IP：

- DNS Server：`192.168.4.103`

**目前會解析的名稱**

- `ns1.home.arpa -> 192.168.4.103`
- `router.home.arpa -> 192.168.4.1`
- `nas.home.arpa -> 192.168.4.20`
- `printer.home.arpa -> 192.168.4.30`
- `dns.home.arpa -> ns1.home.arpa`
- `tuffy.myddns.me -> 192.168.4.103`

**要改哪裡**

- 如果你要新增或修改 `xxx.home.arpa`
  - 編輯 [coredns/zones/db.home.arpa](./coredns/zones/db.home.arpa)
- 如果你要覆寫公開網域，例如 `tuffy.myddns.me`
  - 編輯 [coredns/Corefile](./coredns/Corefile) 裡的 `hosts` 區塊
- 如果你要修改這台 DNS 主機自己監聽的 IP
  - 編輯本機 `.env` 裡的 `DNS_BIND_IP`

**`Corefile` 的用途**

- [coredns/Corefile](./coredns/Corefile) 是 CoreDNS 的主設定檔
- 它負責決定：
  - 哪些網域要由這台 DNS 自己回答
  - 哪些網域要改寫成本機指定 IP
  - 哪些查詢要轉送到外部 DNS
- 你可以把它想成「DNS 的流量規則表」

**`Corefile` 每行意思**

目前內容如下：

```txt
home.arpa:53 {
    errors
    file /etc/coredns/zones/db.home.arpa
    cache 300
    reload
}

.:53 {
    errors
    health
    ready
    hosts {
        192.168.4.103 tuffy.myddns.me
        fallthrough
    }
    forward . 168.95.1.1 1.1.1.1 8.8.8.8 {
        policy sequential
        health_check 5s
        max_fails 2
    }
    cache 300
    loop
    reload
    loadbalance
}
```

- `home.arpa:53 {`
  - 宣告 `home.arpa` 這個 zone 由這台 DNS 在 `53` port 處理
- `errors`
  - 發生 DNS 處理錯誤時，輸出錯誤資訊到日誌
- `file /etc/coredns/zones/db.home.arpa`
  - 指定 `home.arpa` 的資料來源是這份 zone 檔
- `cache 300`
  - 查詢結果快取 `300` 秒，減少重複查詢
- `reload`
  - 偵測檔案變更後自動重新載入設定
- `}`
  - 結束 `home.arpa` 這段規則
- `.:53 {`
  - 宣告其餘所有網域都走這段預設規則
- `health`
  - 開啟健康檢查端點，方便確認 CoreDNS 是否正常
- `ready`
  - 開啟 ready 狀態端點，確認設定是否完成載入
- `hosts {`
  - 用靜態主機對應表，直接覆寫特定網域
- `192.168.4.103 tuffy.myddns.me`
  - 查詢 `tuffy.myddns.me` 時，直接回 `192.168.4.103`
- `fallthrough`
  - 如果 `hosts` 內沒有命中，就繼續往下面規則處理
- `forward . 168.95.1.1 1.1.1.1 8.8.8.8 {`
  - 把其他查不到的網域轉送到這三台外部 DNS
- `policy sequential`
  - 依序使用上游 DNS，先問第一台，再問下一台
- `health_check 5s`
  - 每 `5` 秒檢查一次上游 DNS 健康狀態
- `max_fails 2`
  - 某台上游連續失敗 `2` 次後，暫時視為異常
- `loop`
  - 避免 DNS 轉送規則誤設造成查詢循環
- `loadbalance`
  - 回應多筆記錄時調整順序，避免固定同一筆排第一個

**什麼時候改 `Corefile`**

- 你要覆寫公開網域時，例如 `tuffy.myddns.me`
- 你要調整外部 DNS 上游時
- 你要新增更多靜態覆寫名稱時
- 你要變更快取、健康檢查或轉送策略時

**`db.home.arpa` 在做什麼**

- `$ORIGIN home.arpa.`
  - 表示這份檔案主要管理 `home.arpa` 這個內部網域
- `$TTL 300`
  - 表示 DNS 快取時間為 `300` 秒
- `SOA`
  - 這個 zone 的管理資訊，平常不需要常改
- `NS`
  - 指定誰是這個 zone 的名稱伺服器
- `A`
  - 把名稱對應到 IPv4 位址
- `CNAME`
  - 建立別名

**`db.home.arpa` 的用途**

- [coredns/zones/db.home.arpa](./coredns/zones/db.home.arpa) 是 `home.arpa` 這個內部網域的資料表
- 這份檔案專門回答像下面這種名稱：
  - `ns1.home.arpa`
  - `router.home.arpa`
  - `nas.home.arpa`
  - `printer.home.arpa`
- 你可以把它想成「內網設備名稱對照表」

**`db.home.arpa` 每行意思**

目前內容如下：

```dns
$ORIGIN home.arpa.
$TTL 300

@       IN  SOA ns1.home.arpa. admin.home.arpa. (
            2026070202 ; serial
            3600       ; refresh
            1800       ; retry
            1209600    ; expire
            300 )      ; minimum

        IN  NS  ns1.home.arpa.

ns1     IN  A   192.168.4.103
router  IN  A   192.168.4.1
nas     IN  A   192.168.4.20
printer IN  A   192.168.4.30

dns     IN  CNAME ns1.home.arpa.
```

- `$ORIGIN home.arpa.`
  - 後面如果只寫 `ns1`，實際上代表的是 `ns1.home.arpa`
- `$TTL 300`
  - 這份 zone 內的記錄預設快取 `300` 秒
- `@ IN SOA ns1.home.arpa. admin.home.arpa. (`
  - `SOA` 是這個 zone 的主要管理資訊
  - `@` 代表 zone 自己，也就是 `home.arpa`
  - `ns1.home.arpa.` 是這個 zone 的主要 DNS 主機
  - `admin.home.arpa.` 代表管理者聯絡資訊
- `2026070202 ; serial`
  - zone 版本號
  - 每次修改這份檔案時，建議把這個值加大
- `3600 ; refresh`
  - 其他 DNS 若有同步這份 zone，每 `3600` 秒檢查一次更新
- `1800 ; retry`
  - 檢查更新失敗時，`1800` 秒後再試一次
- `1209600 ; expire`
  - 太久無法更新時，最多保留舊資料多久
- `300 ; minimum`
  - 舊式用途是最小 TTL，現在通常可理解成預設快取參考值
- `IN NS ns1.home.arpa.`
  - 宣告 `ns1.home.arpa` 是這個 `home.arpa` zone 的名稱伺服器
- `ns1 IN A 192.168.4.103`
  - `ns1.home.arpa -> 192.168.4.103`
- `router IN A 192.168.4.1`
  - `router.home.arpa -> 192.168.4.1`
- `nas IN A 192.168.4.20`
  - `nas.home.arpa -> 192.168.4.20`
- `printer IN A 192.168.4.30`
  - `printer.home.arpa -> 192.168.4.30`
- `dns IN CNAME ns1.home.arpa.`
  - `dns.home.arpa` 是 `ns1.home.arpa` 的別名

**什麼時候改 `db.home.arpa`**

- 你要新增新的內網設備名稱時
- 你要修改既有設備 IP 時
- 你要增加 `home.arpa` 下的別名時
- 你要把範例主機名稱換成你自己的命名方式時

**新增一筆內網主機範例**

如果你想新增 `pc.home.arpa -> 192.168.4.50`，可以在 `db.home.arpa` 加這一行：

```dns
pc      IN  A   192.168.4.50
```

改完後重新載入：

```bash
docker compose restart
```

**覆寫公開網域範例**

如果你之後想再多加一個：

- `camera.myddns.me -> 192.168.4.120`

可以在 `coredns/Corefile` 的 `hosts` 區塊加入：

```txt
192.168.4.120 camera.myddns.me
```

改完後重新載入：

```bash
docker compose restart
```

**為什麼使用 `home.arpa`**

- `home.arpa` 是保留給家庭或內部網路使用的特殊網域
- 比起自創假的頂級網域，這樣更不容易和公網名稱衝突
- 也比較能避免把內部主機名稱誤送到外部 DNS

**安全與隱私注意**

- 不要提交 `.env`
- 如果你不想公開內網 IP，提交前請檢查 `coredns/zones/db.home.arpa`
- 預設沒有開啟 query log，可減少使用者查詢紀錄外流
- Docker 容器採唯讀檔案系統，並移除多數不必要能力
- 建議在主機防火牆或路由器 ACL 限制只有內網可存取 `53/tcp` 與 `53/udp`
- `home.arpa` 內未定義的名稱不會被轉送到外部 DNS

**推 GitHub 前的安全注意**

- 不要提交 `.env`
- 如果這份 repo 要公開，請先確認 `db.home.arpa` 內是否包含你不想曝光的內網設備名稱或 IP
- 提交前先執行：

```bash
git status
```

**常用指令**

- 檢查 Compose 設定：

```bash
docker compose config
```

- 查看執行狀態：

```bash
docker compose ps
```

- 查看日誌：

```bash
docker compose logs -f
```

- 重啟服務：

```bash
docker compose restart
```

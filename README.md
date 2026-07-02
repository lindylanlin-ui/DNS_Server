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

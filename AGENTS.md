# AGENTS.md

本文件適用於整個 repository，供在此專案中工作的自動化代理與協作者使用。

## 專案目標

這是一個以 Docker Compose 執行 CoreDNS 的內部 DNS 服務。它負責：

- 權威回覆 `home.arpa` 內部 zone。
- 透過 `hosts` 覆寫少數指定網域。
- 將其他查詢依序轉送至外部 DNS resolver。
- 將 CoreDNS query log 寫入 `logs/coredns.log`，並以 logrotate 輪替。

本專案沒有應用程式測試框架；變更主要透過 Compose 設定檢查、CoreDNS 啟動狀態與實際 DNS 查詢驗證。

## 重要檔案

- `docker-compose.yml`：服務、網路埠、唯讀掛載、權限與日誌設定。
- `Dockerfile`：從固定版本的 CoreDNS image 複製 binary 到 Alpine runtime。
- `coredns/Corefile`：zone、靜態覆寫、上游 resolver、快取與日誌規則。
- `coredns/zones/db.home.arpa`：`home.arpa` 的 SOA、NS、A 與 CNAME records。
- `.env.example`：可提交的環境變數範例。
- `.env`：本機設定，不得提交或在輸出中洩漏內容。
- `logrotate/dns_server_coredns`：主機端 logrotate 規則。
- `README.md`：使用者文件；行為或操作方式改變時應同步更新。

實際設定檔是行為的 source of truth。若 README 的範例與設定檔不一致，先依設定檔確認目前行為，再在同一變更中修正文件。

## 變更規則

### CoreDNS 與 zone

- 保持 `home.arpa` 查詢由專用 server block 處理；未定義的內部名稱不得意外轉送到公網 DNS。
- 新增 `home.arpa` 記錄時，編輯 `coredns/zones/db.home.arpa`，不要放進 `Corefile` 的公網覆寫 `hosts` block。
- 修改 zone 內任何 record 時，必須把 SOA serial 改為更大的值。沿用 `YYYYMMDDNN` 格式，例如當天第一次修改用 `2026071201`，同一天後續修改依序增加尾碼。
- FQDN（例如 SOA、NS、CNAME 的 target）需以 `.` 結尾，避免被 `$ORIGIN` 再次附加。
- CNAME owner 不得同時存在 A、AAAA 或其他資料記錄。
- 內網 IP、主機名稱及 query log 可能是敏感資訊；只加入任務明確需要的資料。
- 調整 upstream resolver、快取、健康檢查或 plugin 順序時，需說明行為與失敗模式的影響。

### Docker 與執行環境

- 同時保留 `53/udp` 與 `53/tcp` 的 port mapping；DNS 不能只開 UDP。
- 維持最小權限原則：容器預設為唯讀、drop capabilities，僅保留綁定低埠所需能力。
- 不要把主機專屬的 bind IP 寫死在 `docker-compose.yml`；使用 `DNS_BIND_IP`，並保留安全的 loopback fallback。
- Docker image 版本應明確固定。升級 CoreDNS 或 Alpine 時，需閱讀 release notes，完成 build 與 DNS smoke test，並同步 README 的版本資訊。
- 未經要求，不執行 `docker compose down -v`、刪除 log、修改主機防火牆，或安裝 `/etc/logrotate.d/` 規則。

### 機密與 repository 衛生

- 不提交 `.env`、實際 log、壓縮 log 或其他本機產物；只保留 `logs/.gitkeep`。
- 不要在診斷輸出、測試紀錄或 commit 中印出 `.env` 內容。
- 修改 `.env.example` 時只使用無敏感性的文件用範例值。
- 保留使用者既有且與任務無關的變更，不任意回復或重新格式化其他檔案。

## 建議工作流程

1. 先閱讀與任務相關的設定檔及 README 段落。
2. 修改前執行 `git status --short`，避免覆蓋既有工作。
3. 進行最小範圍變更；設定行為改變時同步 README。
4. 依下方清單驗證，並在交付說明中列出已執行及未執行的檢查。
5. 提交前再次檢查 diff，特別確認沒有 `.env`、logs 或非預期的內網資訊。

## 驗證清單

至少執行不會啟動服務的靜態檢查：

```sh
docker compose config --quiet
git diff --check
```

若 Docker daemon 可用且變更涉及 image、Compose 或 CoreDNS 設定，再執行：

```sh
docker compose build
docker compose up -d
docker compose ps
```

以 `.env` 中設定的 DNS 主機 IP 進行 smoke test（不要把該值提交到檔案）：

```sh
dig @<DNS_BIND_IP> ns1.home.arpa A +short
dig @<DNS_BIND_IP> home.arpa SOA +short
dig @<DNS_BIND_IP> openai.com A +short
dig +tcp @<DNS_BIND_IP> ns1.home.arpa A +short
```

驗證重點：

- 內部 A/CNAME records 回覆預期值。
- SOA serial 已增加。
- 公網查詢能透過 upstream resolver 回覆。
- UDP 與 TCP 查詢皆成功。
- `docker compose ps` 顯示服務正常，`logs/coredns.log` 沒有新的 parse error、loop 或持續性 upstream timeout。

若環境沒有 Docker、`dig` 或無法綁定 53 port，不要宣稱整合驗證成功；清楚記錄限制與尚待人工執行的命令。

## 文件與提交風格

- README 面向使用者，以繁體中文及可直接複製的命令為主。
- 註解應說明規則存在的原因，避免只是重述設定內容。
- commit 聚焦單一目的；建議使用簡潔的祈使句描述，例如 `新增印表機內部 DNS 記錄`。

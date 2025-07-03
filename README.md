# extract-file-paths

CloudFrontログファイル（.gz形式）から特定のファイルパスを検索し、結果をCSV形式で出力するツール

## 概要

このスクリプトは、CloudFrontアクセスログ（.gz圧縮ファイル）を解析し、指定されたファイルパスに関連するアクセスログを抽出してCSV形式で出力します。

## 機能

- 指定ディレクトリ内の全ての.gzファイルを検索
- 特定のファイルパスを含むログエントリの抽出
- CSV形式での出力（date, time, c-ip, cs-uri-stem）
- 既存出力ファイルに対する追記・上書き選択
- 出力ディレクトリの自動作成
- 検索結果のプレビュー表示

## 使用方法

```bash
./extract_file_paths_csv.sh "検索したいファイルパス" "出力ファイル名" "検索ディレクトリ"
```

### 例

```bash
./extract_file_paths_csv.sh "search.html" "output.csv" "/Users/nakashidev-user/workspace/sample-dir"
```

## 引数

1. **検索したいファイルパス**: 検索対象のファイルパス（例: "search.html"）
2. **出力ファイル名**: 結果を保存するCSVファイルのパス
3. **検索ディレクトリ**: .gzファイルが格納されているディレクトリのパス

## 出力形式

CSV形式で以下の列を出力します：

- `date`: アクセス日付
- `time`: アクセス時刻
- `c-ip`: クライアントIPアドレス
- `cs-uri-stem`: リクエストされたURIパス

## 注意事項

- CloudFrontログ形式（タブ区切り）に特化して設計されています
- 検索対象ファイルパスはcs-uri-stemの末尾と一致する想定です
- 既存の出力ファイルがある場合は、追記または上書きを選択できます

## 必要環境

- bash
- zgrep (gzipファイルのgrep)
- 標準的なUnix/Linuxコマンド (sed, head, tail, wc等)

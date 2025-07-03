#!/bin/bash

# .gzファイル内からファイルパスを検索してCSV形式で出力するスクリプト
# 使用方法: ./extract_file_paths_csv.sh "検索したいファイルパス" "出力ファイル名" "検索ディレクトリ"

if [ $# -lt 3 ]; then
    echo "使用方法: $0 \"検索したいファイルパス\" \"出力ファイル名\" \"検索ディレクトリ\""
    echo "例: $0 \"search.html\" \"output.csv\" \"/Users/nakashidev-user/workspace/sample-dir\""
    exit 1
fi

SEARCH_PATH="$1"
OUTPUT_FILE="$2"
SEARCH_DIR="$3"

# ディレクトリの存在確認
if [ ! -d "$SEARCH_DIR" ]; then
    echo "エラー: 指定されたディレクトリが存在しません: $SEARCH_DIR"
    exit 1
fi

# 出力ファイルのディレクトリを取得
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")

# 出力ファイルのディレクトリが存在しない場合は作成
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "出力ディレクトリが存在しないため作成します: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "エラー: 出力ディレクトリの作成に失敗しました: $OUTPUT_DIR"
        exit 1
    fi
fi

# 出力ファイルが既に存在する場合の確認（追記モード）
APPEND_MODE=false
if [ -f "$OUTPUT_FILE" ]; then
    echo "出力ファイルが既に存在します: $OUTPUT_FILE"
    echo "選択してください:"
    echo "  1) 追記する (a)"
    echo "  2) 上書きする (o)"
    echo "  3) 中止する (c)"
    read -p "選択 [a/o/c]: " -n 1 -r
    echo
    case $REPLY in
        [Aa])
            APPEND_MODE=true
            echo "追記モードで実行します"
            ;;
        [Oo])
            APPEND_MODE=false
            echo "上書きモードで実行します"
            ;;
        *)
            echo "処理を中止しました"
            exit 0
            ;;
    esac
fi

echo "検索対象ディレクトリ: $SEARCH_DIR"
echo "検索ファイルパス: $SEARCH_PATH"
echo "出力ファイル名: $OUTPUT_FILE"
if [ "$APPEND_MODE" = true ]; then
    echo "出力モード: 追記"
else
    echo "出力モード: 新規作成/上書き"
fi
echo "----------------------------------------"

# 一時ファイルを作成
TEMP_FILE=$(mktemp)
FOUND_COUNT=0

# CSVヘッダーを追加（新規作成の場合のみ）
if [ "$APPEND_MODE" = false ]; then
    echo "date,time,c-ip,cs-uri-stem" > "$TEMP_FILE"
fi

# ディレクトリ内のすべての.gzファイルを検索
for gz_file in "$SEARCH_DIR"/*.gz; do
    if [ -f "$gz_file" ]; then
        echo "検索中: $(basename "$gz_file")"

        # .gzファイル内から指定のファイルパスを含む行を検索
        if zgrep -q "$SEARCH_PATH" "$gz_file" 2>/dev/null; then
            FOUND_COUNT=$((FOUND_COUNT + 1))
            echo "  ✓ $(basename "$gz_file") で見つかりました"

            # 一時的な処理ファイルを作成
            PROCESS_FILE=$(mktemp)
            zgrep "$SEARCH_PATH" "$gz_file" 2>/dev/null > "$PROCESS_FILE"

            # 各行を処理
            while IFS= read -r line; do
                # CloudFrontログ形式の解析
                # コメント行をスキップ
                if [[ "$line" =~ ^#.* ]]; then
                    continue
                fi

                # タブ区切りでフィールドを分割
                IFS=$'\t' read -ra fields <<< "$line"

                # 各フィールドを抽出
                # 0:date 1:time 2:x-edge-location 3:sc-bytes 4:c-ip 5:cs-method 6:cs(Host) 7:cs-uri-stem
                if [ ${#fields[@]} -ge 8 ]; then
                    date="${fields[0]}"
                    time="${fields[1]}"
                    c_ip="${fields[4]}"
                    cs_uri_stem="${fields[7]}"

                    # cs-uri-stemが検索対象で終わるかチェック
                    if [[ "$cs_uri_stem" != *"$SEARCH_PATH" ]]; then
                        continue
                    fi

                    # CSVエスケープ処理（カンマやダブルクォートが含まれる場合）
                    date=$(echo "$date" | sed 's/"/\"\"/g')
                    time=$(echo "$time" | sed 's/"/\"\"/g')
                    c_ip=$(echo "$c_ip" | sed 's/"/\"\"/g')
                    cs_uri_stem=$(echo "$cs_uri_stem" | sed 's/"/\"\"/g')

                    # 必要に応じてダブルクォートで囲む
                    if [[ "$date" == *","* ]]; then
                        date="\"$date\""
                    fi
                    if [[ "$time" == *","* ]]; then
                        time="\"$time\""
                    fi
                    if [[ "$c_ip" == *","* ]]; then
                        c_ip="\"$c_ip\""
                    fi
                    if [[ "$cs_uri_stem" == *","* ]]; then
                        cs_uri_stem="\"$cs_uri_stem\""
                    fi

                    # CSV行として出力
                    echo "$date,$time,$c_ip,$cs_uri_stem" >> "$TEMP_FILE"
                fi
            done < "$PROCESS_FILE"

            # 処理ファイルを削除
            rm -f "$PROCESS_FILE"
        fi
    fi
done

# 結果を確認
if [ $FOUND_COUNT -gt 0 ]; then
    echo ""
    echo "========================================="
    echo "検索結果:"
    echo "  対象ファイルパス: $SEARCH_PATH"
    echo "  該当する.gzファイル数: $FOUND_COUNT"

    # データ行数をカウント（ヘッダーを除く）
    if [ "$APPEND_MODE" = false ]; then
        DATA_LINES=$(($(wc -l < "$TEMP_FILE") - 1))
    else
        DATA_LINES=$(wc -l < "$TEMP_FILE")
    fi
    echo "  該当行数: $DATA_LINES"
    echo "========================================="

    # 結果を出力ファイルに保存（追記 or 上書き）
    if [ "$APPEND_MODE" = true ]; then
        cat "$TEMP_FILE" >> "$OUTPUT_FILE"
    else
        mv "$TEMP_FILE" "$OUTPUT_FILE"
    fi

    # 出力ファイルの作成確認
    if [ $? -eq 0 ]; then
        echo ""
        if [ "$APPEND_MODE" = true ]; then
            echo "✓ 結果を $OUTPUT_FILE に追記しました"
        else
            echo "✓ 結果を $OUTPUT_FILE に出力しました"
        fi
    else
        echo ""
        echo "✗ エラー: 出力ファイルの操作に失敗しました"
        exit 1
    fi

    echo ""
    echo "今回の検索結果プレビュー（最初の10行）:"
    # ヘッダーを含めて表示
    if [ "$APPEND_MODE" = false ]; then
        head -11 "$OUTPUT_FILE"  # ヘッダー + データ10行
        TOTAL_LINES=$(wc -l < "$OUTPUT_FILE")
        if [ $TOTAL_LINES -gt 11 ]; then
            echo "..."
            echo "(今回の検索で $DATA_LINES 行のデータ)"
        fi
    else
        cat "$TEMP_FILE" | head -10
        if [ $DATA_LINES -gt 10 ]; then
            echo "..."
            echo "(今回の検索で $DATA_LINES 行の結果)"
        fi
    fi

    if [ "$APPEND_MODE" = true ]; then
        echo ""
        echo "出力ファイル全体の行数: $(wc -l < "$OUTPUT_FILE")"
    fi
else
    echo ""
    echo "✗ '$SEARCH_PATH' を含む行が見つかりませんでした"

    echo ""
    echo "◯ '$SEARCH_PATH' を含む行が見つかりました！"
fi

# 一時ファイルのクリーンアップ
rm -f "$TEMP_FILE"

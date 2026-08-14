#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
TMP_DIR="${TMPDIR:-/tmp}"
PID_FILE="$TMP_DIR/wallpaper-picker-ueberzugpp-$USER-$$"

cleanup() {
    if [[ -n "$SOCKET" ]]; then
        ueberzugpp cmd -s "$SOCKET" -a exit 2>/dev/null
    fi
    rm -f "$PID_FILE"
}

trap cleanup EXIT INT TERM HUP

# --------------------------------------------------
# Terminal title
# --------------------------------------------------

printf '\033]0;Wallpaper Picker\007'

# --------------------------------------------------
# Start ueberzugpp daemon (socket mode)
# --------------------------------------------------

ueberzugpp layer \
    --no-stdin \
    --silent \
    --use-escape-codes \
    --output x11 \
    --pid-file "$PID_FILE"

UB_PID=$(cat "$PID_FILE" 2>/dev/null)
SOCKET="$TMP_DIR/ueberzugpp-$UB_PID.socket"

# --------------------------------------------------
# Start wallpaper picker
# --------------------------------------------------
#
# Each line fed to fzf is "basename<TAB>fullpath".
# --with-nth=1 displays only the basename.
# {2} in the preview/selection refers to the fullpath field directly,
# so there's no external lookup file and nothing that needs exporting
# across the fzf preview subprocess boundary.

while true; do

    selected=$(
        find "$WALLPAPER_DIR" -type f \
            \( \
                -iname '*.jpg' \
                -o -iname '*.jpeg' \
                -o -iname '*.png' \
                -o -iname '*.webp' \
                -o -iname '*.bmp' \
            \) \
            -printf '%f\t%p\n' |
        sort -t $'\t' -k1,1 -f -u |
        fzf \
            --height=100% \
            --layout=reverse \
            --border \
            --prompt='Wallpaper > ' \
            --delimiter='\t' \
            --with-nth=1 \
            --preview-window='right:60%:border-left' \
            --preview="ueberzugpp cmd \
                -s '$SOCKET' \
                -i wallpaper-preview \
                -a add \
                -x \$FZF_PREVIEW_LEFT \
                -y \$FZF_PREVIEW_TOP \
                --max-width \$FZF_PREVIEW_COLUMNS \
                --max-height \$FZF_PREVIEW_LINES \
                -f {2}"
    )

    # Escape / Ctrl-C
    [[ -z "$selected" ]] && break

    selected_path=$(cut -f2 <<< "$selected")

    [[ -z "$selected_path" ]] && continue

    # Set wallpaper
    feh --bg-fill "$selected_path"

    # DO NOT exit.
    # Loop back into fzf.

done

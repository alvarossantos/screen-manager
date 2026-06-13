#!/bin/bash
# screen-manager-actions.sh
# Helper script para ações do plugin screen-manager
# Uso: screen-manager-actions.sh <ação> [argumentos]
#
# Ações:
#   disable-with-move <output>     - Move todas as janelas de <output> para outro e desliga
#   mirror <source> <destination>  - Espelha source sobre destination
#   enable <output>               - Liga uma tela
#   enable-all                    - Liga todas as telas conectadas
#   focus-and-move <target_output> - Foca em cada janela do output atual e move para target

set -euo pipefail

ACTION="${1:-}"
shift || true

# ─── Helpers ──────────────────────────────────────────────────────────────────

get_workspaces_on_output() {
    local target_output="$1"
    niri msg -j workspaces | jq -r ".[] | select(.output == \"$target_output\") | .id"
}

get_windows_on_output() {
    local target_output="$1"
    # Pega workspaces do output, depois janelas nesses workspaces
    local ws_ids
    ws_ids=$(get_workspaces_on_output "$target_output")
    
    if [ -z "$ws_ids" ]; then
        return
    fi
    
    # Para cada workspace, pegar as janelas
    for ws_id in $ws_ids; do
        niri msg -j windows | jq -r ".[] | select(.workspace_id == $ws_id) | .id"
    done
}

get_other_output() {
    local exclude_output="$1"
    niri msg -j outputs | jq -r "keys[] | select(. != \"$exclude_output\")" | head -1
}

focus_window_by_id() {
    local window_id="$1"
    niri msg action focus-window --id "$window_id" 2>/dev/null || true
}

# ─── Ação: disable-with-move ─────────────────────────────────────────────────
# Move todas as janelas de um output para outro e desliga

disable_with_move() {
    local target_output="$1"
    local dest_output
    dest_output=$(get_other_output "$target_output")
    
    if [ -z "$dest_output" ]; then
        echo "ERROR: No other output found to move windows to"
        exit 1
    fi
    
    echo "Moving windows from '$target_output' to '$dest_output'..."
    
    # Pegar todas as janelas no output alvo
    local window_ids
    window_ids=$(get_windows_on_output "$target_output")
    
    if [ -z "$window_ids" ]; then
        echo "No windows found on '$target_output'"
    else
        local count=0
        for wid in $window_ids; do
            count=$((count + 1))
            echo "  Moving window $wid..."
            # Focar na janela e mover para o outro monitor
            focus_window_by_id "$wid"
            sleep 0.2
            niri msg action move-column-to-monitor "$dest_output" 2>/dev/null || true
            sleep 0.1
        done
        echo "Moved $count window(s)"
    fi
    
    # Esperar um pouco para o Niri processar
    sleep 0.5
    
    # Desligar o output
    echo "Disabling output '$target_output'..."
    niri msg output "$target_output" off
    echo "Done"
}

# ─── Ação: mirror ────────────────────────────────────────────────────────────
# Espelha um output sobre outro usando wlr-randr

mirror_output() {
    local source="$1"
    local destination="$2"
    
    if [ "$source" = "$destination" ]; then
        echo "ERROR: Source and destination must be different"
        exit 1
    fi
    
    # Verificar se wl-mirror está disponível
    if command -v wl-mirror &>/dev/null; then
        echo "Mirroring '$source' to '$destination' using wl-mirror..."
        # Matar processo wl-mirror anterior se existir
        pkill -f "wl-mirror" 2>/dev/null || true
        sleep 0.3
        # Iniciar wl-mirror em background
        nohup wl-mirror --fullscreen-output "$destination" "$source" > /dev/null 2>&1 &
        echo "Mirror started (PID: $!)"
    else
        echo "ERROR: wl-mirror not installed. Install it with: pacman -S wl-mirror"
        exit 1
    fi
}

# ─── Ação: enable ────────────────────────────────────────────────────────────

enable_output() {
    local output="$1"
    echo "Enabling output '$output'..."
    niri msg output "$output" on
    echo "Done"
}

# ─── Ação: enable-all ────────────────────────────────────────────────────────
# Liga todos os outputs conectados

enable_all_outputs() {
    echo "Enabling all connected outputs..."
    local outputs
    outputs=$(niri msg -j outputs | jq -r 'keys[]')
    
    if [ -z "$outputs" ]; then
        echo "No outputs found"
        return
    fi
    
    local count=0
    for output in $outputs; do
        count=$((count + 1))
        echo "  Enabling '$output'..."
        niri msg output "$output" on 2>/dev/null || true
    done
    
    echo "Enabled $count output(s)"
}

# ─── Ação: focus-and-move-all ────────────────────────────────────────────────
# Move todas as janelas de um output para outro (focando em cada uma)

focus_and_move_all() {
    local source_output="$1"
    local dest_output
    dest_output=$(get_other_output "$source_output")
    
    if [ -z "$dest_output" ]; then
        echo "ERROR: No other output found"
        exit 1
    fi
    
    local window_ids
    window_ids=$(get_windows_on_output "$source_output")
    
    if [ -z "$window_ids" ]; then
        echo "No windows to move"
        return
    fi
    
    local count=0
    for wid in $window_ids; do
        count=$((count + 1))
        focus_window_by_id "$wid"
        sleep 0.2
        niri msg action move-column-to-monitor "$dest_output" 2>/dev/null || true
        sleep 0.1
    done
    
    echo "Moved $count window(s) from '$source_output' to '$dest_output'"
}

# ─── Main ────────────────────────────────────────────────────────────────────

case "$ACTION" in
    disable-with-move)
        disable_with_move "$1"
        ;;
    mirror)
        mirror_output "$1" "$2"
        ;;
    enable)
        enable_output "$1"
        ;;
    enable-all)
        enable_all_outputs
        ;;
    focus-and-move)
        focus_and_move_all "$1"
        ;;
    *)
        echo "Usage: $0 <action> [args]"
        echo "Actions:"
        echo "  disable-with-move <output>       Move windows and disable output"
        echo "  mirror <source> <destination>    Mirror source to destination"
        echo "  enable <output>                  Enable an output"
        echo "  enable-all                       Enable all connected outputs"
        echo "  focus-and-move <output>          Move all windows from output"
        exit 1
        ;;
esac
#!/usr/bin/env bash
# cloudinary.sh
#
# Keeps the attendee's Cloudinary key (CLOUDINARY_URL) without ever printing
# it. Apps with photo or file uploads store them on Cloudinary and read
# CLOUDINARY_URL, in development and on Render.
# Installed to ~/.workshop/cloudinary.sh by handoff.sh. The sign-in skill
# runs 'save', auth.sh runs 'check', and the app-session notes run 'install'.
#
#   bash cloudinary.sh save            save what the attendee copied; prints SAVED, NEXT or INVALID
#   bash cloudinary.sh check           is a key saved in ~/.workshop/cloudinary.env?
#   bash cloudinary.sh install [app]   put it in the app's .env.development.local (default: .)
#
# Cloudinary's console shows the API environment variable only as a format,
# CLOUDINARY_URL=cloudinary://<your_api_key>:<your_api_secret>@<cloud_name>,
# so 'save' also takes it in three copies: that format (for the cloud name),
# then the API Key, then the API Secret. It keeps the pieces in a private
# file until the last one arrives.

set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

WORKSHOP_DIR="$HOME/.workshop"
ENV_FILE="$WORKSHOP_DIR/cloudinary.env"
PENDING_FILE="$WORKSHOP_DIR/cloudinary.pending"
AGAIN='then run: bash ~/.workshop/cloudinary.sh save'


# Is this a cloud name, API key or API secret as Cloudinary issues them? Only
# these characters, which also keeps the saved line safe to source in a shell
# (the deploy recipe does); at least one letter or digit, since a hidden
# secret can show as dots; and not a placeholder from Cloudinary's docs.
#   valid_piece <minimum length> <text>
valid_piece() {
    local min=$1 piece=$2
    [[ $piece =~ ^[A-Za-z0-9._-]+$ && $piece =~ [A-Za-z0-9] && ${#piece} -ge $min ]] || return 1
    case "$(printf '%s' "$piece" | tr '[:upper:]' '[:lower:]')" in
        api_key | api_secret | my_key | my_secret | your_api_key | your_api_secret | cloud_name | my_cloud_name | your_cloud_name)
            return 1 ;;
    esac
    return 0
}

# Splits cloudinary://KEY:SECRET@CLOUD into url_key, url_secret and url_cloud,
# which the caller declares local, if every part is valid.
split_url() {
    [[ $1 =~ ^cloudinary://([^:@/]+):([^:@/]+)@([^:@/]+)$ ]] || return 1
    url_key=${BASH_REMATCH[1]}
    url_secret=${BASH_REMATCH[2]}
    url_cloud=${BASH_REMATCH[3]}
    valid_piece 6 "$url_key" && valid_piece 6 "$url_secret" && valid_piece 1 "$url_cloud"
}


# Prints the clipboard's text without carriage returns, a byte-order mark or
# surrounding spaces. Callers capture it; it must never reach the terminal.
read_clipboard() {
    local text
    text=$(paste_text) || return 1
    text=${text//$'\r'/}
    text=${text#$'\xef\xbb\xbf'}
    text=${text#"${text%%[![:space:]]*}"}
    text=${text%"${text##*[![:space:]]}"}
    printf '%s' "$text"
}

# Prints its argument without one pair of surrounding quotes.
unquote() {
    case "$1" in
        \"*\" | \'*\') printf '%s' "${1:1:${#1}-2}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Empties the clipboard, so the secret is not pasted somewhere later.
clear_clipboard() {
    copy_text ''
}

# Writes a file only this user can read, replacing any earlier one in one step.
write_private() {
    local file=$1 tmp
    mkdir -p "$WORKSHOP_DIR"
    tmp=$(mktemp "$file.XXXXXX") || return 1
    printf '%s\n' "$2" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$file"
}

# Asks Cloudinary whether it accepts the key and secret. They reach curl on
# stdin, never on a command line, and -q (which must come first) ignores any
# ~/.curlrc that could turn on verbose or trace output. Returns 0 (accepted),
# 1 (rejected) or 2 (no answer, so it cannot tell).
verify() {
    local cloud=$1 key=$2 secret=$3 code
    code=$(printf 'user = "%s:%s"\n' "$key" "$secret" \
        | curl -q -s -o /dev/null -w '%{http_code}' --max-time 20 -K - "https://api.cloudinary.com/v1_1/$cloud/ping")
    case "$code" in
        200) return 0 ;;
        401) return 1 ;;
        *) return 2 ;;
    esac
}

# Prints the saved CLOUDINARY_URL line if it has the right shape.
saved_line() {
    local line="" url_key url_secret url_cloud
    IFS= read -r line 2>/dev/null < "$ENV_FILE"
    if [[ $line != CLOUDINARY_URL=* ]] || ! split_url "${line#CLOUDINARY_URL=}"; then
        return 1
    fi
    printf '%s' "$line"
}

finish() {
    local cloud=$1 key=$2 secret=$3 confirmed
    verify "$cloud" "$key" "$secret"
    case $? in
        0) confirmed="Cloudinary accepted it." ;;
        1)
            # Keep the cloud name: the key or the secret was copied wrong.
            write_private "$PENDING_FILE" "$cloud"
            echo "INVALID: Cloudinary did not accept this API Key and API Secret. Ask the attendee to copy the API Key again, $AGAIN (the API Secret comes next)."
            return 1 ;;
        *) confirmed="Cloudinary could not be reached to confirm it; the app's first upload will show whether it works." ;;
    esac
    write_private "$ENV_FILE" "CLOUDINARY_URL=cloudinary://$key:$secret@$cloud" \
        || { echo "[FAIL] could not write $ENV_FILE"; return 1; }
    rm -f "$PENDING_FILE"
    clear_clipboard && confirmed="$confirmed The clipboard was emptied."
    echo "SAVED: the Cloudinary key is in ~/.workshop/cloudinary.env, readable only by this user. $confirmed"
}

save() {
    local text cloud="" key="" url_key url_secret url_cloud format_cloud=""
    text=$(read_clipboard) || { echo "INVALID: could not read $CLIPBOARD."; return 1; }
    # The pending file holds the cloud name, then the API Key, one per line.
    if [ -f "$PENDING_FILE" ]; then
        { IFS= read -r cloud; IFS= read -r key; } < "$PENDING_FILE"
    fi

    case "$text" in
        "") echo "INVALID: the clipboard is empty. Ask the attendee to click the copy button again, $AGAIN"; return 1 ;;
        *$'\n'*) echo "INVALID: the clipboard holds several lines, not one Cloudinary value. Ask the attendee to use the copy button next to the value, $AGAIN"; return 1 ;;
    esac
    text=$(unquote "$text")
    text=${text#export }
    text=${text#CLOUDINARY_URL=}
    text=$(unquote "$text")

    if split_url "$text"; then
        finish "$url_cloud" "$url_key" "$url_secret"
        return
    fi
    if [[ $text == cloudinary://* ]]; then
        # The console's format: placeholders for the key and secret, then the
        # real cloud name.
        [[ $text =~ ^cloudinary://[^@]*@([^@]+)$ ]] && format_cloud=${BASH_REMATCH[1]}
        if [[ $text == *'<'* ]] && valid_piece 1 "$format_cloud"; then
            write_private "$PENDING_FILE" "$format_cloud" || { echo "[FAIL] could not write $PENDING_FILE"; return 1; }
            echo "NEXT: Cloudinary shows the API environment variable with placeholders, so the API Key and API Secret are copied one at a time. Ask the attendee to click the copy button next to the API Key (in the list of keys on the same page), $AGAIN"
            return 0
        fi
        echo "INVALID: that is not the attendee's whole Cloudinary key: it holds placeholders from Cloudinary's docs or a hidden secret (dots or stars). On their API Keys page, ask them to click the copy button next to API environment variable, $AGAIN"
        return 1
    fi

    # One value on its own: the API Key, then the API Secret, after the format.
    if [ -z "$cloud" ]; then
        echo "INVALID: that is not the API environment variable, which holds the attendee's cloud name and comes first. On the API Keys page, ask them to click the copy button next to API environment variable, $AGAIN"
        return 1
    fi
    if [ -z "$key" ]; then
        if ! valid_piece 6 "$text" || [ "$text" = "$cloud" ]; then
            echo "INVALID: that is not the API Key. Ask the attendee to click the copy button next to the API Key, $AGAIN"
            return 1
        fi
        write_private "$PENDING_FILE" "$cloud"$'\n'"$text" || { echo "[FAIL] could not write $PENDING_FILE"; return 1; }
        echo "NEXT: now the API Secret, from the same row. Ask the attendee to click the eye button to show it (Cloudinary may ask them to confirm it is them first), then its copy button, $AGAIN"
        return 0
    fi
    if ! valid_piece 6 "$text" || [ "$text" = "$key" ] || [ "$text" = "$cloud" ]; then
        echo "INVALID: that is not the API Secret (a hidden secret shows as dots or stars). Ask the attendee to click the eye button next to the API Secret to show it, then its copy button, $AGAIN"
        return 1
    fi
    finish "$cloud" "$key" "$text"
}

check() {
    [ -f "$ENV_FILE" ] || { echo "not saved yet"; return 1; }
    saved_line >/dev/null || { echo "no valid CLOUDINARY_URL in ~/.workshop/cloudinary.env; save it again"; return 1; }
    echo "saved in ~/.workshop/cloudinary.env"
}

install_into_app() {
    local dir=$1 line target tmp status
    line=$(saved_line) || { echo "MISSING: no Cloudinary key is saved. Have the attendee run /workshop-signin in a new session (it redoes only what is missing), then run this again."; return 1; }
    [ -f "$dir/config/application.rb" ] || { echo "[FAIL] $dir is not a Rails app folder"; return 1; }
    # bin/lint-env rejects keys that the app's .env.example does not mention,
    # and only apps with uploads mention CLOUDINARY_URL.
    if [ ! -f "$dir/config/initializers/cloudinary.rb" ] && ! grep -qs 'service: *Cloudinary' "$dir/config/storage.yml"; then
        echo "NOT NEEDED: this app has no photo or file uploads, so it does not read CLOUDINARY_URL. Nothing was written."
        return 0
    fi
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        && ! git -C "$dir" check-ignore -q .env.development.local; then
        echo "[FAIL] Git does not ignore $dir/.env.development.local, so the key could be committed. Nothing was written."
        return 1
    fi

    target="$dir/.env.development.local"
    tmp=$(mktemp "$target.XXXXXX") || return 1
    if [ -f "$target" ]; then
        grep -vE '^[[:space:]]*(export[[:space:]]+)?CLOUDINARY_URL[[:space:]]*=' "$target" > "$tmp"
        status=$?
        [ "$status" -le 1 ] || { rm -f "$tmp"; echo "[FAIL] could not read $target"; return 1; }
    fi
    if ! { printf '%s\n' "$line" >> "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$target"; }; then
        rm -f "$tmp"
        echo "[FAIL] could not write $target"
        return 1
    fi
    echo "INSTALLED: CLOUDINARY_URL is in $target, readable only by this user. Restart the web app so it reads it."
}


case "${1:-}" in
    save) save ;;
    check) check ;;
    install) install_into_app "${2:-.}" ;;
    *)
        echo "usage: cloudinary.sh save | check | install [app folder]"
        exit 2
        ;;
esac

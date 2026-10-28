#!/usr/bin/env bash
# Short-lived setup input. No file writes and no shell evaluation of answers.
prc_confirm() {
    local question="$1" answer
    while true; do
        printf '%s%s' "$question" "$(prc_text common.confirm)" >&2
        read -r answer || return 1
        case "${answer,,}" in
            1|s|sim|y|yes) return 0 ;;
            ''|2|n|nao|não|no) return 1 ;;
            *) prc_message shell.answer_invalid >&2 ;;
        esac
    done
}

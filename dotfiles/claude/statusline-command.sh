#!/usr/bin/env bash
# Claude Code status line — mirrors ~/.config/starship.toml (left + right_format).
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# ~ for $HOME, then keep only the last segment (the status line is narrower than
# the shell, so starship's truncation_length=3 pushes the right side off-screen).
# Segments longer than 24 chars keep their tail.
rel_cwd="${cwd/#$HOME/\~}"
leaf="${rel_cwd##*/}"
if [ ${#leaf} -gt 24 ]; then
  short_cwd="…${leaf: -23}"
elif [ "$rel_cwd" = "~" ] || [ "$rel_cwd" = "/" ] || [ "$rel_cwd" = "/$leaf" ] || [ "$rel_cwd" = "~/$leaf" ]; then
  short_cwd="$rel_cwd"
else
  short_cwd="…/${leaf}"
fi

hex() { printf '%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
fg() { printf '\033[38;2;%sm' "$(hex "$1")"; }
bg() { printf '\033[48;2;%sm' "$(hex "$1")"; }
R=$'\033[0m'
B=$'\033[1m'
PURPLE=9A348E PINK=DA627D SALMON=FCA17D LBLUE=86BBD8 TEAL=06969A DBLUE=33658A
DARK=1E1E2E WHITE=FFFFFF
L_CAP=$'' R_CAP=$'' ARROW_R=$'' ARROW_L=$'' BRANCH=$''

# starship git_status: $all_status$ahead_behind with default symbols
git_status=""
branch=""
if porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null); then
  branch=$(awk '/^# branch.head /{print $3}' <<< "$porcelain")
  [ "$branch" = "(detached)" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  read -r ahead behind < <(awk '/^# branch.ab /{gsub(/[+-]/,""); print $3, $4}' <<< "$porcelain")
  conflicted=0 stashed=0 deleted=0 renamed=0 modified=0 staged=0 untracked=0
  while IFS= read -r line; do
    case "$line" in
      u\ *) conflicted=1 ;;
      \?\ *) untracked=1 ;;
      [12]\ *)
        xy="${line:2:2}"
        [ "${line:0:1}" = "2" ] && renamed=1
        [ "${xy:0:1}" != "." ] && staged=1
        case "${xy:1:1}" in M) modified=1 ;; D) deleted=1 ;; esac
        [ "${xy:0:1}" = "D" ] && deleted=1 ;;
    esac
  done <<< "$porcelain"
  git -C "$cwd" --no-optional-locks rev-parse -q --verify refs/stash >/dev/null 2>&1 && stashed=1
  [ "$conflicted" = 1 ] && git_status+="="
  [ "$stashed" = 1 ]    && git_status+="\$"
  [ "$deleted" = 1 ]    && git_status+="✘"
  [ "$renamed" = 1 ]    && git_status+="»"
  [ "$modified" = 1 ]   && git_status+="!"
  [ "$staged" = 1 ]     && git_status+="+"
  [ "$untracked" = 1 ]  && git_status+="?"
  ahead=${ahead:-0} behind=${behind:-0}
  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then git_status+="⇕"
  elif [ "$ahead" -gt 0 ]; then git_status+="⇡"
  elif [ "$behind" -gt 0 ]; then git_status+="⇣"
  fi
fi

ctx_str=""
[ -n "$used_pct" ] && ctx_str=" · $(printf '%.0f' "$used_pct")%"

out=""
# ── left (format) ──
out+="$(fg $PURPLE)${L_CAP}$(bg $PURPLE) "
out+="$(fg $PURPLE)$(bg $PINK)${ARROW_R}"
out+="$(bg $PINK)$(fg $DARK)${B} ${short_cwd} ${R}"
out+="$(fg $PINK)$(bg $SALMON)${ARROW_R}"
if [ -n "$branch" ]; then
  out+="$(bg $SALMON)$(fg $DARK)${B} ${BRANCH} ${branch} ${git_status} ${R}"
fi
out+="$(fg $SALMON)$(bg $LBLUE)${ARROW_R}"
# light-blue slot (language versions in the shell) carries the model + context
out+="$(bg $LBLUE)$(fg $DARK)${B} ${model}${ctx_str} ${R}"
out+="$(fg $LBLUE)$(bg $TEAL)${ARROW_R}${R}$(fg $TEAL)${ARROW_R}${R}"
left="$out"

# ── right (right_format) ──
out="$(fg $SALMON)${ARROW_L}"
out+="$(bg $SALMON)$(fg $DARK)${B} $(whoami) ${R}"
out+="$(bg $SALMON)$(fg $PINK)${ARROW_L}"
out+="$(bg $PINK)$(fg $DARK)${B} @ ${R}"
out+="$(bg $PINK)$(fg $LBLUE)${ARROW_L}"
out+="$(bg $LBLUE)$(fg $DARK)${B} $(hostname -s) ${R}"
out+="$(bg $LBLUE)$(fg $TEAL)${ARROW_L}"
out+="$(bg $TEAL)$(fg $DARK)${B} ♥ $(date +%H:%M) ${R}"
out+="$(bg $TEAL)$(fg $DBLUE)${ARROW_L}"
out+="$(bg $DBLUE)$(fg $WHITE)${B} 📅 $(date +%Y-%m-%d) ${R}"
out+="$(fg $DBLUE)${R_CAP}${R}"

right="$out"

# Right-align like starship's right_format. Claude Code exports COLUMNS; the
# status line sits inside a 2-col indent with a margin on the right, so leave 6.
visible() { local t; t=$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'); echo $(( ${#t} + 1 )); }  # +1: 📅 is double-width
gap=$(( ${COLUMNS:-0} - 6 - $(visible "$left") - $(visible "$right") ))
[ "$gap" -lt 2 ] && gap=2
printf '%s%*s%s' "$left" "$gap" "" "$right"

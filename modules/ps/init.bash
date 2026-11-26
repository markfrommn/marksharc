_ms_bash_set_option _ms_ps_bash_executable "${BASH_SOURCE[0]%/*}/bin/ms-ps"
# Set through the ownership helper above.
# shellcheck disable=SC2154
_ms_ps_bash() { command "$_ms_ps_bash_executable" "${_ms_opt_ps_procs-on}" "$@"; }
pss() { _ms_ps_bash all plain "$@"; }
pssj() { _ms_ps_bash all jobs "$@"; }
psj() { _ms_ps_bash all jobs; }
pssu() { _ms_ps_bash own plain "$@"; }
pssuj() { _ms_ps_bash own jobs "$@"; }
psuj() { _ms_ps_bash own jobs; }
psju() { _ms_ps_bash own jobs; }

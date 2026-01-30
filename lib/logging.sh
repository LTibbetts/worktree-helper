# logging.sh - Color definitions and logging functions

# Colors (disable with NO_COLOR env var)
if [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

log_info() { echo -e "${BLUE}info:${RESET} $*"; }
log_success() { echo -e "${GREEN}✓${RESET} $*"; }
log_warn() { echo -e "${YELLOW}warn:${RESET} $*"; }
log_error() { echo -e "${RED}error:${RESET} $*" >&2; }

die() { log_error "$@"; exit 1; }

#!/usr/bin/env bash
set -euo pipefail

# Patch MicroPico extension so that manualComDevice skips serial port enumeration
# (useful for boards with custom VID/PID). Usage:
#   ./scripts/patch_micropico.sh [--dry-run] [EXTENSION_DIR]
#
# EXTENSION_DIR defaults to the latest paulober.pico-w-go-* under ~/.vscode/extensions

DRY_RUN=0
EXT_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    *) EXT_ARG="$1" ;;
  esac
  shift
done

candidates=$(ls -d "$HOME"/.vscode/extensions/paulober.pico-w-go-* 2>/dev/null | tr '\n' ' ')
EXT_DIR=${EXT_ARG:-$(ls -td "$HOME"/.vscode/extensions/paulober.pico-w-go-* 2>/dev/null | head -1)}
if [[ -z "${EXT_DIR}" || ! -d "${EXT_DIR}" ]]; then
  echo "Extension directory not found. Specify it explicitly." >&2
  exit 1
fi
[[ -z "${EXT_ARG}" && -n "${candidates}" ]] && { echo "Found extensions:"; printf '  %s\n' ${candidates}; }

TARGET="${EXT_DIR}/dist/extension.js"
if [[ ! -f "${TARGET}" ]]; then
  echo "Target file not found: ${TARGET}" >&2
  exit 1
fi

BACKUP_FILE="${TARGET}.bak.$(date +%Y%m%d%H%M%S)"
echo "Patching ${TARGET}"
echo "Backup will be saved to ${BACKUP_FILE}"
[[ ${DRY_RUN} -eq 1 ]] && { echo "Dry run requested; exiting before patch."; exit 0; }

if grep -Fq "Manual COM open failed" "${TARGET}" && grep -Fq "this.settings?.getString(I.manualComDevice)" "${TARGET}"; then
  echo "Appears already patched (Manual COM block found). Skipping."
  exit 0
fi

cp -p "${TARGET}" "${BACKUP_FILE}"

new_block='const t=()=>{this.ui?.refreshState(!1),this.settings?.reload();const e=this.settings?.getString(I.manualComDevice)??"";if(e.length>0){clearInterval(this.autoConnectTimer),this.autoConnectTimer=void 0,this.comDevice=e,w.x8.getInstance().openSerialPort(e).catch(o=>{this.logger.error("Manual COM open failed: "+o)});return}const n=this.settings?.getBoolean(I.autoConnect);if(!n)return;w.x8.getSerialPorts().then(async r=>{if(0!==r.length){if(clearInterval(this.autoConnectTimer),!this.comDevice||!r.includes(this.comDevice)||(await w.x8.getInstance().openSerialPort(this.comDevice),await new Promise(e=>setTimeout(e,1e3)),w.x8.getInstance().isPortDisconnected())){const e=r[0];this.comDevice=e,await w.x8.getInstance().openSerialPort(e),await new Promise(e=>setTimeout(e,1e3));this.autoConnectTimer=setInterval(t,1500)}}else this.noCheckForUSBMSDs||(this.noCheckForUSBMSDs=!0,await this.checkForUSBMSDs())}).catch(e=>{this.logger.error("Failed to get serial ports: "+e)})};return t(),this.settings?.getString(I.manualComDevice)?.length>0?!0:(this.autoConnectTimer=setInterval(t,1500),!0)}'

tmp="$(mktemp "${TARGET}".XXXXXX)"
trap 'rm -f "${tmp}"' EXIT

if ! awk -v RS='\0' -v ORS='' -v nb="${new_block}" '
{
  setup = match($0, /setupAutoConnect\(\)\{/);
  tpos_rel = setup ? match(substr($0, setup), /const t=\(\)=>\{/) : 0;
  tpos = tpos_rel ? setup + tpos_rel - 1 : 0;
  end_rel = tpos ? match(substr($0, tpos), /async checkForUSBMSDs\(\)\{/) : 0;
  endpos = end_rel ? tpos + end_rel - 1 : 0;
  if (!setup || !tpos || !endpos || endpos <= tpos) {
    printf "Markers not found; aborting\n" > "/dev/stderr";
    exit 1;
  }
  printf "%s%s%s", substr($0, 1, tpos - 1), nb, substr($0, endpos);
}
' "${TARGET}" > "${tmp}"; then
  echo "awk patch failed" >&2
  exit 1
fi

if [[ ! -s "${tmp}" ]]; then
  echo "Patched file is empty; aborting" >&2
  exit 1
fi

mv "${tmp}" "${TARGET}"
trap - EXIT

echo "Patched successfully."

echo "Done. Backup saved as ${BACKUP_FILE}"

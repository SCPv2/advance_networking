#!/bin/bash
set -euo pipefail

# ----- 설정 -----
REPO_OWNER="SCPv2"
REPO_NAME="ce_advance_networking"
SUBPATH="05_vpn/ceweb"
DEST="/home/rocky/ceweb"

# ----- 준비 -----
sudo dnf update -y
sudo dnf upgrade -y
sudo dnf install -y epel-release
sudo dnf install -y wget curl git vim nano htop net-tools bind-utils
echo "200 nic2" | sudo tee -a /etc/iproute2/rt_tables
# Auto-Scaling에서 생성할 경우 아래 두 라인 삭제 또는 마스킹
sudo ip route add default via 10.1.1.1 dev eth1 table nic2             # web: 10.1.1.1, app: 10.1.2.1 
sudo ip rule add from 10.1.1.10/32 lookup nic2 priority 100            # web: 10.1.1.10/32, app: 10.1.2.20/32

mkdir -p "${DEST}"
# 필요 유틸
if ! command -v curl >/dev/null 2>&1; then
  (command -v dnf >/dev/null 2>&1 && sudo dnf -y install curl tar rsync) \
  || (command -v yum >/dev/null 2>&1 && sudo yum -y install curl tar rsync)
fi

TMPDIR="$(mktemp -d)"
LOG="/var/log/ceweb_init.log"
exec > >(tee -a "$LOG") 2>&1

echo "[INFO] Start fetching ${REPO_OWNER}/${REPO_NAME}:${SUBPATH} -> ${DEST}"

# ----- main → master 순서로 시도 -----
SUCCESS=0
for BR in main master; do
  URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${BR}.tar.gz"
  echo "[INFO] Trying branch: ${BR} (${URL})"

  rm -rf "${TMPDIR:?}"/* || true
  if curl -fL "${AUTH_HEADER[@]}" "$URL" | tar -xz -C "$TMPDIR"; then
    SRC_DIR="${TMPDIR}/${REPO_NAME}-${BR}/${SUBPATH}"
    if [[ -d "$SRC_DIR" ]]; then
      # 대상 비우고(원치 않으면 주석 처리), 새로운 내용 반영
      rm -rf "${DEST:?}/"* || true
      rsync -a "$SRC_DIR"/ "${DEST}/"
      SUCCESS=1
      echo "[INFO] Copied ${SRC_DIR} -> ${DEST}"
      break
    else
      echo "[WARN] Subpath not found in archive: ${SRC_DIR}"
    fi
  else
    echo "[WARN] Download/extract failed for branch ${BR}"
  fi
done

if [[ "$SUCCESS" -ne 1 ]]; then
  echo "[ERROR] Failed to fetch ${SUBPATH} from ${REPO_OWNER}/${REPO_NAME} (main/master)."
  exit 1
fi

# 권한 정리(있는 경우에만)
if id rocky >/dev/null 2>&1; then
  chown -R rocky:rocky "${DEST}"
fi
chmod -R u=rwX,go=rX "${DEST}"

echo "[INFO] Done. See log: ${LOG}"

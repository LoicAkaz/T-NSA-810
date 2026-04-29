#!/bin/bash
################################################################################
# bootstrap.sh — Configure ansible-pull sur un VPS
# Usage: sudo bash bootstrap.sh [chemin/vers/config.env]
# À exécuter UNE SEULE FOIS sur chaque VPS (ou pour reconfigurer).
################################################################################

set -euo pipefail

CONFIG_FILE="${1:-./config.env}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Fichier de configuration '$CONFIG_FILE' introuvable"
    echo "Usage: sudo bash $0 config.env"
    exit 1
fi

source "$CONFIG_FILE"

# Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()     { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error()   { echo -e "${RED}[✗] $1${NC}"; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

[ "$EUID" -ne 0 ] && error "Ce script doit être exécuté en root (sudo)"

################################################################################

log "Configuration: $CONFIG_FILE"
echo ""
echo "  Hostname   : $SERVER_HOSTNAME"
echo "  Dépôt      : $REPO_URL ($REPO_BRANCH)"
echo "  Cron       : $CRON_SCHEDULE"
echo "  Log        : $LOG_FILE"
echo ""

# ── 1. Hostname ─────────────────────────────────────────────────────────────
log "Définition du hostname → $SERVER_HOSTNAME"
hostnamectl set-hostname "$SERVER_HOSTNAME"
# Mettre à jour /etc/hosts pour que le hostname se résolve localement
if ! grep -q "127.0.1.1" /etc/hosts; then
    echo "127.0.1.1 $SERVER_HOSTNAME" >> /etc/hosts
else
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $SERVER_HOSTNAME/" /etc/hosts
fi
success "Hostname défini : $(hostname)"

# ── 2. Dépendances ──────────────────────────────────────────────────────────
log "Mise à jour des paquets et installation des dépendances..."
if command -v apt-get &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq ansible git curl logrotate
elif command -v dnf &>/dev/null; then
    dnf install -y ansible git logrotate --exclude=curl
elif command -v yum &>/dev/null; then
    yum install -y ansible git curl logrotate
else
    error "Aucun gestionnaire de paquets supporté trouvé"
fi
success "Dépendances installées (ansible $(ansible --version | head -1 | awk '{print $3}'))"

# ── 3. Clé SSH deploy (dépôt privé) ─────────────────────────────────────────
if [ -n "$DEPLOY_KEY_PATH" ]; then
    if [ ! -f "$DEPLOY_KEY_PATH" ]; then
        error "Clé SSH introuvable : $DEPLOY_KEY_PATH"
    fi
    log "Installation de la clé SSH deploy..."
    mkdir -p "$(dirname "$DEPLOY_KEY_DEST")"
    if [ "$DEPLOY_KEY_PATH" != "$DEPLOY_KEY_DEST" ]; then
        cp "$DEPLOY_KEY_PATH" "$DEPLOY_KEY_DEST"
    fi
    chmod 600 "$DEPLOY_KEY_DEST"
    # Configurer SSH pour utiliser cette clé avec le dépôt
    SSH_CONFIG="/root/.ssh/config"
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    REPO_HOST=$(echo "$REPO_URL" | sed -E 's|.*@([^:/]+).*|\1|')
    if ! grep -q "Host $REPO_HOST" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" <<EOF

Host $REPO_HOST
    IdentityFile $DEPLOY_KEY_DEST
    StrictHostKeyChecking accept-new
EOF
    fi
    success "Clé SSH deploy configurée pour $REPO_HOST"
else
    warning "Aucune clé SSH deploy configurée (dépôt public ou clé déjà présente)"
fi

# ── 3b. Vault password ───────────────────────────────────────────────────────
# Copie ~/.vault_pass de l'utilisateur courant (avant sudo) vers /root/.vault_pass
INVOKING_USER="${SUDO_USER:-$USER}"
VAULT_PASS_SRC="/home/$INVOKING_USER/.vault_pass"
VAULT_PASS_DEST="/root/.vault_pass"
if [ -f "$VAULT_PASS_SRC" ]; then
    log "Copie de $VAULT_PASS_SRC → $VAULT_PASS_DEST"
    cp "$VAULT_PASS_SRC" "$VAULT_PASS_DEST"
    chmod 600 "$VAULT_PASS_DEST"
    success "Vault password installé dans $VAULT_PASS_DEST"
else
    warning "Fichier $VAULT_PASS_SRC introuvable — vault non configuré"
fi

# ── 4. Rotation des logs ─────────────────────────────────────────────────────
log "Configuration de la rotation des logs..."
cat > /etc/logrotate.d/ansible-pull <<EOF
$LOG_FILE {
    daily
    rotate $LOG_RETENTION_DAYS
    compress
    missingok
    notifempty
    create 640 root root
}
EOF
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"
success "Rotation des logs configurée ($LOG_RETENTION_DAYS jours)"

# ── 5. Script de pull ────────────────────────────────────────────────────────
PULL_SCRIPT="/usr/local/bin/ansible-pull-run"
log "Création du script de pull → $PULL_SCRIPT"
cat > "$PULL_SCRIPT" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

source /etc/ansible-pull.env

echo ""
echo "════════════════════════════════════════"
echo "  ansible-pull — $(date +'%Y-%m-%d %H:%M:%S')"
echo "  Host: $(hostname)"
echo "════════════════════════════════════════"

VAULT_ARGS=""
[ -f /root/.vault_pass ] && VAULT_ARGS="--vault-password-file /root/.vault_pass"

ansible-pull \
    -U "$REPO_URL" \
    -C "$REPO_BRANCH" \
    -i inventory/hosts.yml \
    --limit "$(hostname -s)" \
    $VAULT_ARGS \
    "$PLAYBOOK"

SCRIPT
chmod 750 "$PULL_SCRIPT"
success "Script de pull créé"

# ── 6. Fichier d'environnement pour le script de pull ───────────────────────
log "Écriture de /etc/ansible-pull.env..."
cat > /etc/ansible-pull.env <<EOF
REPO_URL="$REPO_URL"
REPO_BRANCH="$REPO_BRANCH"
PLAYBOOK="$PLAYBOOK"
EOF
chmod 600 /etc/ansible-pull.env
success "Environnement écrit dans /etc/ansible-pull.env"

# ── 7. Cron ─────────────────────────────────────────────────────────────────
log "Configuration du cron ($CRON_SCHEDULE)..."
CRON_LINE="$CRON_SCHEDULE root $PULL_SCRIPT >> $LOG_FILE 2>&1"
mkdir -p /etc/cron.d
CRON_FILE="/etc/cron.d/ansible-pull"
echo "$CRON_LINE" > "$CRON_FILE"
chmod 644 "$CRON_FILE"
systemctl enable --now crond 2>/dev/null || systemctl enable --now cron 2>/dev/null || true
success "Cron configuré : $CRON_FILE"

# ── 8. Premier pull ──────────────────────────────────────────────────────────
echo ""
log "Lancement du premier ansible-pull..."
echo ""
if bash "$PULL_SCRIPT" 2>&1 | tee -a "$LOG_FILE"; then
    success "Premier pull réussi"
else
    warning "Premier pull échoué — vérifiez les logs : $LOG_FILE"
fi

# ── Résumé ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  Bootstrap terminé${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo "  Hostname     : $(hostname)"
echo "  Dépôt        : $REPO_URL"
echo "  Cron         : $CRON_SCHEDULE"
echo "  Script pull  : $PULL_SCRIPT"
echo "  Logs         : $LOG_FILE"
echo ""

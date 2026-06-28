#!/usr/bin/env bash
# ============================================================
# 🏥 Clínica WhatsApp · Instalador Linux Mint / Debian 13
# ============================================================
# Instala: Docker, Docker Compose, configura firewall, prepara
# o projeto pra subir com um único comando.
#
# Uso:
#   chmod +x scripts/install-linux-mint.sh
#   ./scripts/install-linux-mint.sh
# ============================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }

# checa se é root
if [[ $EUID -ne 0 ]]; then
   err "Roda como root: sudo $0"
   exit 1
fi

# detecta usuário real (não root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
log "Usuário: $REAL_USER · Home: $REAL_HOME"

# -----------------------------------------
# 1) Atualiza sistema
# -----------------------------------------
log "Atualizando pacotes..."
apt update -qq && apt upgrade -y -qq
ok "Sistema atualizado"

# -----------------------------------------
# 2) Dependências básicas
# -----------------------------------------
log "Instalando dependências..."
apt install -y -qq \
    ca-certificates curl wget git nano htop \
    apt-transport-https software-properties-common \
    gnupg lsb-release ufw jq openssl
ok "Dependências instaladas"

# -----------------------------------------
# 3) Docker Engine
# -----------------------------------------
if ! command -v docker &> /dev/null; then
    log "Instalando Docker..."

    # adiciona chave GPG oficial
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg

    # detecta codinome (mint based on ubuntu noble usa "noble", debian usa "trixie")
    . /etc/os-release
    DISTRO_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-bookworm}}"

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${DISTRO_CODENAME} stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update -qq
    apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    ok "Docker instalado: $(docker --version)"
else
    ok "Docker já instalado: $(docker --version)"
fi

# -----------------------------------------
# 4) Usuário no grupo docker (sem precisar sudo)
# -----------------------------------------
if ! groups "$REAL_USER" | grep -q docker; then
    log "Adicionando $REAL_USER ao grupo docker..."
    usermod -aG docker "$REAL_USER"
    warn "Precisa fazer logout/login pra aplicar a mudança"
fi

# habilita docker no boot
systemctl enable --now docker
ok "Docker rodando"

# -----------------------------------------
# 5) Verifica docker compose
# -----------------------------------------
if ! docker compose version &> /dev/null; then
    err "docker compose não encontrado!"
    exit 1
fi
ok "Docker Compose: $(docker compose version)"

# -----------------------------------------
# 6) Firewall (UFW)
# -----------------------------------------
log "Configurando firewall..."
ufw --force reset > /dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
# NÃO vamos abrir 5678, 8080, 5432, etc — só via Caddy
ufw --force enable
ok "Firewall ativo (SSH + HTTP + HTTPS apenas)"

# -----------------------------------------
# 7) Prepara o projeto
# -----------------------------------------
PROJECT_DIR="$REAL_HOME/clinica-whatsapp-n8n"

if [[ ! -d "$PROJECT_DIR" ]]; then
    log "Clonando projeto em $PROJECT_DIR..."
    sudo -u "$REAL_USER" git clone <REPO_DO_PROJETO> "$PROJECT_DIR" || {
        warn "Não consegui clonar (esperado se ainda não tem repo)."
        log "Criando diretório manualmente..."
        mkdir -p "$PROJECT_DIR"
        chown -R "$REAL_USER:$REAL_USER" "$PROJECT_DIR"
    }
fi

cd "$PROJECT_DIR"

# cria .env se não existir
if [[ ! -f .env ]]; then
    log "Criando .env a partir do exemplo..."
    cp .env.example .env
    chown "$REAL_USER:$REAL_USER" .env

    # gera chave aleatória pra Evolution
    EVO_KEY=$(openssl rand -hex 32)
    sed -i "s/^EVO_APIKEY=$/EVO_APIKEY=$EVO_KEY/" .env

    # gera verify token pra Meta
    META_TOKEN=$(openssl rand -hex 32)
    sed -i "s/^META_VERIFY_TOKEN=$/META_VERIFY_TOKEN=$META_TOKEN/" .env

    warn "Edite .env e preencha N8N_HOST e credenciais Meta:"
    warn "   nano .env"
fi

# -----------------------------------------
# 8) Domínio & DNS
# -----------------------------------------
echo ""
log "===== PRÓXIMOS PASSOS ====="
echo ""
echo "1) Edite o .env com seus dados:"
echo "   cd $PROJECT_DIR && nano .env"
echo ""
echo "2) Aponte o DNS do seu domínio pra este servidor:"
ip=$(curl -s https://api.ipify.org || echo "<IP_DO_SERVIDOR>")
echo "   Tipo A: atendimento.SEU_DOMINIO.com.br → $ip"
echo ""
echo "3) Ajuste o Caddyfile:"
echo "   nano $PROJECT_DIR/caddy/Caddyfile"
echo "   (trocar SEU_DOMINIO pelo seu domínio real)"
echo ""
echo "4) Suba os containers:"
echo "   docker compose up -d"
echo ""
echo "5) Acompanhe os logs:"
echo "   docker compose logs -f n8n"
echo ""
echo "6) Acesse o n8n:"
echo "   https://atendimento.SEU_DOMINIO.com.br"
echo ""

ok "Instalação concluída!"
warn "Faça logout/login pra o grupo docker fazer efeito."

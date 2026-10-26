#!/usr/bin/env bash
# Instalador do Framework de Edição Dinâmica para macOS (Apple Silicon ou Intel). Equivalente do instalar.ps1.
# Pode rodar quantas vezes quiser: o que já está certo é pulado.
# Uso (na raiz do repositório):  bash 00_SISTEMA/instalacao/instalar.sh [--sem-opcionais]
set -u
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
MOTOR="$RAIZ/00_SISTEMA/motor"
DEP="$AQUI/dependencias.json"
SEM_OPC=0; [ "${1:-}" = "--sem-opcionais" ] && SEM_OPC=1
RES=(); FALTAS=0

# Homebrew no PATH mesmo em shell sem profile (Apple Silicon e Intel)
for b in /opt/homebrew/bin /usr/local/bin; do [ -d "$b" ] && case ":$PATH:" in *":$b:"*) ;; *) PATH="$b:$PATH";; esac; done
export PATH

passo() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
nota() { # item status detalhe
	RES+=("$2|$1|$3")
	local cor=32; [ "$2" = AVISO ] && cor=33; [ "$2" = FALTA ] && { cor=31; FALTAS=$((FALTAS+1)); }
	printf '   \033[%sm[%s]\033[0m %s: %s\n' "$cor" "$2" "$1" "$3"
}
tem() { command -v "$1" >/dev/null 2>&1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
tam() { stat -f%z "$1"; }
dep() { node -e "const d=require('$DEP');const v=($1);console.log(v===undefined||v===null?'':typeof v==='object'?JSON.stringify(v):v)"; }
baixar() { # url destino
	rm -f "$2.baixando"
	curl -L --fail --silent --show-error --retry 3 -o "$2.baixando" "$1" && mv "$2.baixando" "$2" || { rm -f "$2.baixando"; return 1; }
}

echo "Framework de Edição Dinâmica: $RAIZ"
[ "$(uname -s)" = Darwin ] || echo "   Atenção: este instalador foi feito para macOS; no Linux veja docs/07-LINUX.md."
case "$RAIZ" in *"/Library/Mobile Documents/"*|*"/Dropbox/"*|*"/Google Drive/"*|*"/OneDrive"*) echo "   Atenção: pasta sincronizada na nuvem; o render trava arquivos. Prefira ~/Projetos.";; esac

# 1. Programas (Homebrew) -------------------------------------------------------------------------------------------
passo "Programas (Homebrew): Node.js 24, FFmpeg, Git e yt-dlp"
if ! tem brew; then
	nota brew FALTA 'instale o Homebrew (https://brew.sh; ele pede as Xcode Command Line Tools) com o comando oficial: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" e rode este instalador de novo'
else
	# se o comando já existe (ex.: node pelo fnm/nvm), não reinstala
	for i in $(seq 0 $(( $(dep "d.brew.length") - 1 ))); do
		cmd=$(dep "d.brew[$i].comando"); [ -z "$cmd" ] && continue
		opc=$(dep "d.brew[$i].opcional"); [ "$opc" = true ] && [ $SEM_OPC = 1 ] && continue
		if ! tem "$cmd"; then
			f=$(dep "d.brew[$i].formula"); echo "   instalando $f..."; brew install "$f"
			[ "$cmd" = node ] && brew link --overwrite --force node@24 >/dev/null 2>&1
		fi
	done
fi
for i in $(seq 0 $(( $(dep "d.brew.length") - 1 ))); do
	cmd=$(dep "d.brew[$i].comando"); [ -z "$cmd" ] && continue
	opc=$(dep "d.brew[$i].opcional"); [ "$opc" = true ] && [ $SEM_OPC = 1 ] && continue
	conf=$(dep "d.brew[$i].conferir"); nt=$(dep "d.brew[$i].nota")
	if tem "$cmd"; then
		if [ "$cmd" = ffmpeg ]; then v=$(ffmpeg -hide_banner -version 2>/dev/null | head -1); else v=$("$cmd" --version 2>/dev/null | head -1); fi
		case "$v" in *"$conf"*) nota "$cmd" OK "$v";; *) nota "$cmd" AVISO "versão diferente da testada: $v";; esac
	else
		[ "$opc" = true ] && nota "$cmd" AVISO "não instalado ($nt)" || nota "$cmd" FALTA "não instalado ($nt)"
	fi
done

# 2. Pastas vazias que o Git não guarda -----------------------------------------------------------------------------
for d in $(node -e "console.log(require('$DEP').pastas_vazias.join('\n'))" 2>/dev/null); do mkdir -p "$RAIZ/$d"; done

# 3. Pacotes do motor e navegador do Remotion -----------------------------------------------------------------------
passo "Pacotes do motor (npm ci, versões travadas no package-lock.json) e navegador do Remotion"
if tem node && tem npm; then
	cd "$MOTOR" || exit 1
	[ -f node_modules/remotion/package.json ] || npm ci --no-audit --no-fund
	rv=""
	if [ -f node_modules/remotion/package.json ]; then
		node node_modules/@remotion/cli/remotion-cli.js browser ensure
		rv=$(node -e "console.log(require('remotion/package.json').version)" 2>/dev/null)
	fi
	esperada=$(dep "d.remotion")
	[ "$rv" = "$esperada" ] && nota remotion OK "versão $rv" || nota remotion FALTA "versão '$rv' (esperada $esperada): apague 00_SISTEMA/motor/node_modules e rode de novo"
	arq=$(uname -m); [ "$arq" = arm64 ] && pk=compositor-darwin-arm64 || pk=compositor-darwin-x64
	# as .dylib do compositor são achadas pela pasta atual: o binário só abre com cwd = pasta dele (o Remotion faz o mesmo)
	if [ -x "node_modules/@remotion/$pk/ffmpeg" ] && (cd "node_modules/@remotion/$pk" && ./ffmpeg -version >/dev/null 2>&1); then nota "compositor Remotion" OK "$pk roda"
	else nota "compositor Remotion" FALTA "$pk não roda (npm ci incompleto?)"; fi
else
	nota "pacotes do motor" FALTA "Node.js não está instalado (passo 1)"
fi

# 4. Modelos e ferramentas baixados ---------------------------------------------------------------------------------
passo "Modelos do Whisper, DeepFilterNet e modelos de ruído"
n=$(node -e "console.log(require('$DEP').downloads.length)")
for i in $(seq 0 $((n-1))); do
	dest=$(dep "d.downloads[$i].destino")
	case "$dest" in *deep-filter.exe) continue;; esac # binário do Windows: o do macOS vem abaixo
	opc=$(dep "d.downloads[$i].opcional"); [ "$opc" = true ] && [ $SEM_OPC = 1 ] && continue
	url=$(dep "d.downloads[$i].url"); bytes=$(dep "d.downloads[$i].bytes"); esp=$(dep "d.downloads[$i].sha256")
	alvo="$RAIZ/$dest"; nome=$(basename "$alvo"); mkdir -p "$(dirname "$alvo")"
	certo() { [ -f "$alvo" ] || return 1; if [ -n "$esp" ]; then [ "$(sha "$alvo")" = "$esp" ]; else [ "$(tam "$alvo")" = "$bytes" ]; fi; }
	certo || { echo "   baixando $nome ($((bytes/1048576)) MB)"; baixar "$url" "$alvo"; }
	if [ ! -f "$alvo" ]; then [ "$opc" = true ] && s=AVISO || s=FALTA; nota "$nome" $s "não baixou (sem internet?): rode de novo"; continue; fi
	if [ -n "$esp" ]; then
		[ "$(sha "$alvo")" = "$esp" ] && nota "$nome" OK "sha256 confere" || nota "$nome" FALTA "sha256 DIFERENTE: apague o arquivo e rode de novo"
	else
		[ "$(tam "$alvo")" = "$bytes" ] && nota "$nome" AVISO "tamanho confere; sha256 não publicado (não conferido)" || nota "$nome" AVISO "tamanho diferente do esperado: apague e rode de novo"
	fi
done
# DeepFilterNet para o Mac
plat="$(uname -s | tr A-Z a-z)-$(uname -m | sed 's/aarch64/arm64/;s/x86_64/x64/')"
durl=$(dep "d.deepfilternet_unix['$plat'].url")
DFN="$RAIZ/00_SISTEMA/ferramentas/deepfilternet/deep-filter"
if [ -z "$durl" ]; then nota deep-filter AVISO "sem binário para $plat (o estúdio de áudio usa o afftdn do FFmpeg)"
else
	dbytes=$(dep "d.deepfilternet_unix['$plat'].bytes"); desp=$(dep "d.deepfilternet_unix['$plat'].sha256")
	mkdir -p "$(dirname "$DFN")"
	if [ ! -f "$DFN" ] || [ "$(tam "$DFN")" != "$dbytes" ]; then echo "   baixando deep-filter ($((dbytes/1048576)) MB)"; baixar "$durl" "$DFN"; fi
	if [ -f "$DFN" ]; then
		chmod +x "$DFN"; xattr -d com.apple.quarantine "$DFN" 2>/dev/null
		if [ -n "$desp" ] && [ "$(sha "$DFN")" != "$desp" ]; then nota deep-filter FALTA "sha256 DIFERENTE: apague $DFN e rode de novo"
		elif "$DFN" --version 2>/dev/null | grep -q '0\.5\.6'; then nota "deep-filter roda" OK "${desp:+sha256 confere; }$("$DFN" --version 2>/dev/null | head -1)"
		else nota "deep-filter roda" FALTA "não abriu (veja docs/01-INSTALAR-MAC.md)"; fi
	else nota deep-filter FALTA "não baixou: rode de novo"; fi
fi

# 5. Efeitos sonoros ------------------------------------------------------------------------------------------------
passo "Efeitos sonoros básicos (gerados por código)"
SFX="$RAIZ/02_BIBLIOTECA/sfx"
lista=$(node -e "console.log(require('$DEP').sfx_sintetizados.join(' '))")
faltam() { local f=""; for s in $lista; do [ -f "$SFX/$s.wav" ] || f="$f $s"; done; echo "$f"; }
if [ -n "$(faltam)" ] && tem node; then (cd "$MOTOR" && node scripts/synth-sfx.mjs "$SFX" >/dev/null); fi
fs="$(faltam)"
if [ -z "$fs" ]; then
	nota "SFX básicos" OK "$(echo $lista | wc -w | tr -d ' ') efeitos em 02_BIBLIOTECA/sfx"
	if tem ffmpeg; then
		saida=$(cd "$MOTOR" && node scripts/sfx-substitutos.mjs 2>&1); cod=$?
		if [ $cod -ne 0 ]; then nota "SFX de terceiros" FALTA "substitutos não criados: $saida"
		elif echo "$saida" | grep -q 'nada a fazer'; then nota "SFX de terceiros" OK "todos os sons chamados pelo nome existem"
		else nota "SFX de terceiros" AVISO "criados substitutos sintetizados (motionix e 05_LAB/sfx); para sons melhores veja 02_BIBLIOTECA/sfx/README.md"; fi
	fi
else nota "SFX básicos" FALTA "faltam:$fs"; fi

# 6. Chaves de API (.env) -------------------------------------------------------------------------------------------
passo "Chaves de API (.env, todas opcionais)"
[ -f "$MOTOR/.env" ] || cp "$MOTOR/.env.example" "$MOTOR/.env"
chaves=$(grep -cE '^[[:space:]]*(GEMINI|PEXELS|PIXABAY)_API_KEY[[:space:]]*=[[:space:]]*[^[:space:]]' "$MOTOR/.env")
[ "$chaves" -ge 1 ] && nota .env OK "$chaves de 3 chaves preenchidas" || nota .env AVISO "nenhuma chave (opcional). Abrir: open -e 00_SISTEMA/motor/.env"

# 7. Marca ----------------------------------------------------------------------------------------------------------
passo "Sua marca (02_BIBLIOTECA/kit/marca/marca.json)"
M="$RAIZ/02_BIBLIOTECA/kit/marca/marca.json"
if [ -f "$M" ]; then
	if ! node -e "JSON.parse(require('fs').readFileSync('$M','utf8'))" 2>/dev/null; then nota marca.json FALTA "arquivo inválido (aspas ou vírgula faltando)"
	elif grep -q seu_perfil "$M"; then nota marca.json AVISO "ainda com o @ de exemplo: preencha antes do primeiro vídeo"
	else nota marca.json OK preenchido; fi
else nota marca.json FALTA "arquivo não encontrado"; fi

# 8. Conferência final ----------------------------------------------------------------------------------------------
passo "Conferência final"
if tem ffmpeg; then
	f=$(ffmpeg -hide_banner -filters 2>/dev/null)
	for fl in whisper arnndn ebur128 drawtext adynamicequalizer firequalizer; do
		echo "$f" | grep -qE " $fl " && nota "ffmpeg: filtro $fl" OK presente || nota "ffmpeg: filtro $fl" FALTA "este FFmpeg não tem o filtro (brew reinstall ffmpeg)"
	done
fi
[ -f /System/Library/Fonts/Supplemental/Arial.ttf ] && nota "Arial do sistema" OK "usada nas folhas de quadros" || nota "Arial do sistema" FALTA "/System/Library/Fonts/Supplemental/Arial.ttf não existe"

echo; printf '%s\n' "${RES[@]}" | awk -F'|' '{printf "%-6s %-34s %s\n",$1,$2,$3}'
if [ $FALTAS -eq 0 ]; then printf '\n\033[32mTUDO PRONTO. Próximo passo: abra o Claude Code na pasta do repositório.\033[0m\n'
else printf '\n\033[33m%s item(ns) FALTA acima. Corrija e rode de novo (docs/01-INSTALAR-MAC.md).\033[0m\n' "$FALTAS"; fi
exit $FALTAS

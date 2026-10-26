# 01 - Instalar no macOS

Equivalente do [01-INSTALAR.md](01-INSTALAR.md) (Windows) para **macOS** (Apple Silicon ou Intel). Tudo o mais (fluxo, formatos, regras) é igual.

## Antes de começar

- macOS 13 ou mais novo, ~10 GB livres, 8 GB de RAM ou mais.
- [Homebrew](https://brew.sh) instalado (veja abaixo).
- Pasta do repositório **fora** de iCloud Drive, Dropbox e Google Drive (ex.: `~/Projetos/...`).

**O que foi testado.** Apple Silicon (arm64) com macOS 27. **Mac Intel e macOS 13 a 26 não foram testados**: o instalador tem o caminho para Intel (`compositor-darwin-x64`, DeepFilterNet `x86_64-apple-darwin`), mas ninguém confirmou que funciona. Se algo falhar, a tabela final do instalador diz o que e onde.

### Homebrew e Xcode Command Line Tools

Sem o Homebrew, o instalador para na linha `brew` com FALTA e mostra este mesmo comando. Instale pelo comando oficial (do [brew.sh](https://brew.sh)), cole no Terminal:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Ele pede as **Xcode Command Line Tools** (se faltarem) e a senha do Mac, e leva alguns minutos. No fim, siga as instruções que ele imprime para pôr o `brew` no PATH (em Apple Silicon fica em `/opt/homebrew/bin`). Depois rode o instalador do framework de novo.

### Confira a pasta do repositório

O `instalar.sh` avisa quando o caminho contém `Library/Mobile Documents` (iCloud Drive), `Dropbox`, `Google Drive` ou `OneDrive`. Na sincronização, o render trava arquivos no meio. Se aparecer o aviso, mova a pasta para `~/Projetos` antes de continuar.

## Instalar

Na raiz do repositório:

```
bash 00_SISTEMA/instalacao/instalar.sh
```

(ou duplo clique em `00_SISTEMA/instalacao/INSTALAR.command`; na 1ª vez, botão direito → Abrir). Pode rodar quantas vezes quiser: o que já está certo é pulado. `--sem-opcionais` pula yt-dlp e os modelos RNNoise/Silero.

O que ele faz: confere/instala Node.js 24, FFmpeg 9 (o do Homebrew já tem os filtros `whisper` e `arnndn`), Git e yt-dlp; cria as pastas vazias; `npm ci` no motor (Remotion 4.0.532 travado); baixa o navegador do Remotion; baixa os modelos do Whisper (~1 GB, sha256 conferido) e o DeepFilterNet 0.5.6 para Mac; gera os efeitos sonoros e os substitutos; cria o `.env`; confere tudo e mostra a tabela **OK / AVISO / FALTA**.

O instalador termina com código de saída igual ao número de itens FALTA (0 = tudo pronto).

## Chaves de API (`.env`)

Arquivo: `00_SISTEMA/motor/.env` (oculto no Finder, não vai para o Git). Abrir:

```
open -e 00_SISTEMA/motor/.env
```

Preencha `GEMINI_API_KEY`, `PEXELS_API_KEY`, `PIXABAY_API_KEY` (todas opcionais), sem espaço nem aspas. Nunca cole chave no chat.

## Marca

```
open -e 02_BIBLIOTECA/kit/marca/marca.json
```

## O que mudou para o Mac

| Item | Windows | macOS |
|---|---|---|
| Instalador | `INSTALAR.bat` + `instalar.ps1` (winget) | `instalar.sh` / `INSTALAR.command` (Homebrew) |
| Binários do Remotion | contorno do Controle Inteligente de Aplicativos (`lib/binarios.mjs`) | não precisa: o compositor `darwin-arm64`/`darwin-x64` roda direto, com `<OffthreadVideo>` disponível |
| Fonte dos rótulos (folhas de quadros) | `C:/Windows/Fonts/arial.ttf` | `/System/Library/Fonts/Supplemental/Arial.ttf` (`scripts/lib/fonte.mjs`) |
| DeepFilterNet | `deep-filter.exe` | `deep-filter` (binário `apple-darwin`) |
| Chrome da `capturar-manchete.mjs` | `Program Files` | `/Applications/Google Chrome.app` (ou Edge/Chromium) |
| Lixeira do `sfx-importar-mixkit.mjs` | PowerShell | Finder (`osascript`) |
| GPU (`--gl=angle`) | Direct3D | Metal, via ANGLE (conferido neste Mac, Apple Silicon: um still e um mp4 de 2 s com o `Video` do `@remotion/media` e `--gl=angle` renderizaram sem erro em 2026-10-26) |

## Contorno de binários do Remotion (`lib/binarios.mjs`)

No Windows, o Controle Inteligente de Aplicativos pode bloquear o `ffmpeg` que vem no pacote do Remotion (`@remotion/compositor-win32-x64-msvc`). Só nesse caso o `scripts/lib/binarios.mjs` troca para o FFmpeg do sistema.

No Mac isso **não é preciso**: o compositor `@remotion/compositor-darwin-arm64` (ou `-darwin-x64` no Intel) roda direto, então o `<OffthreadVideo>` fica disponível. Detalhe técnico: o `ffmpeg` desse pacote só abre com a pasta dele como pasta atual, porque as bibliotecas `.dylib` são achadas pela pasta atual. Rodar `ffmpeg` do pacote de outra pasta dá erro de biblioteca; o Remotion já cuida disso ao renderizar, e o instalador confere o compositor entrando na pasta antes. Você não precisa fazer nada.

## Atenção: regressões

Os limiares de PSNR das regressões (42 e 40 dB) foram medidos no Windows. No Mac, grave o piloto de cada formato **neste computador** (`--gravar`) antes de usar a regressão como trava, e nunca compare com referência gravada em outro sistema.

## Redução de ruído (DeepFilterNet)

O `deep-filter` do Mac só é executado depois de o `sha256` do arquivo baixado conferir (se não bater, o instalador apaga o arquivo e não o executa). O instalador em si só confere o `sha256` e roda `--version`. Em 2026-10-26 o binário foi testado num áudio sintético com ruído, com as mesmas flags do `estudio-audio.mjs` (`--atten-lim-db 12 -D -o`), e reduziu o RMS de -26,6 para -38,6 dB; a qualidade em voz real não foi medida. Se não abrir, ou se a plataforma não tiver binário, o estúdio de áudio usa o filtro `afftdn` do FFmpeg no lugar: a limpeza fica mais simples, mas funciona. O motor roda o filtro `whisper` na CPU (`use_gpu=false`), como no Windows.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `deep-filter` não abre ("desenvolvedor não identificado") | `xattr -d com.apple.quarantine 00_SISTEMA/ferramentas/deepfilternet/deep-filter` e rode o instalador de novo |
| FFmpeg sem filtro `whisper` | `brew reinstall ffmpeg` e confira com `ffmpeg -hide_banner -filters \| grep whisper` |
| `npm ci` falha | apague `00_SISTEMA/motor/node_modules` e rode o instalador de novo. Nunca `npm update` |
| Mac dorme no meio do render | `caffeinate -dimsu node scripts/render.mjs ...` ou peça ao Claude para manter acordado |

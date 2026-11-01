# Installation de git sous Windows — le PRÉREQUIS de tools/bootstrap.sh.
# Sous Windows, aucun shell sh n'existe avant Git for Windows (qui fournit
# Git Bash) : ce script PowerShell comble ce vide via winget. Sans git pour
# cloner, récupérer le dépôt via l'archive d'export de la forge (ZIP).
#
#   powershell -ExecutionPolicy Bypass -File tools\install-git.ps1            # annonce → accord → installe
#   powershell -ExecutionPolicy Bypass -File tools\install-git.ps1 -Oui       # sans question
#   powershell -ExecutionPolicy Bypass -File tools\install-git.ps1 -Verifie   # vérification seule
#
# Même flux consenti que le bootstrap (ADR-0014) : vérifier d'abord (déjà
# présent → on ne touche à rien), annoncer, n'installer qu'avec l'accord.
param(
    [switch]$Oui,
    [switch]$Verifie
)

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Output "ok — git déjà présent : $(git --version)"
    exit 0
}

Write-Output "MANQUANT — git (prérequis du bootstrap)"
if ($Verifie) {
    Write-Output "Mode -Verifie : aucune installation."
    exit 1
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "  → winget absent ; téléchargement manuel : https://git-scm.com/download/win"
    exit 3
}

if (-not $Oui) {
    $reponse = Read-Host "Installer Git for Windows via winget ? [o/N]"
    if ($reponse -notmatch '^(o|O|oui|OUI|y|Y)$') {
        Write-Output "Pas d'installation : git reste à installer (https://git-scm.com/download/win)."
        exit 1
    }
}

winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Output "ok — git installé : $(git --version)"
} else {
    Write-Output "git n'est pas encore visible dans le PATH — rouvrir un terminal, puis"
    Write-Output "contrôler avec : powershell -ExecutionPolicy Bypass -File tools\install-git.ps1 -Verifie"
    exit 3
}

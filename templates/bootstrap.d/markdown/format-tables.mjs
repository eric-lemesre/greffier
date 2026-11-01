#!/usr/bin/env node
// Normalisation des **tableaux GFM** : pipes alignés verticalement, ligne de
// séparateurs comprise — le style `aligned` vérifié par la règle markdownlint
// MD060 (voir .markdownlint-cli2.jsonc). La largeur des cellules est mesurée
// avec `string-width`, la **même bibliothèque que MD060** : le formateur et la
// porte sont donc toujours d'accord (y compris emoji et caractères larges).
//
// MODÈLE à copier dans tools/ d'un projet instancié (avec markdown.sh).
// PÉRIMÈTRE : tous les .md suivis par git, plus les non-suivis non ignorés —
// adapter la liste EXCLUSIONS ci-dessous à votre arborescence, en phase avec
// les globs de .markdownlint-cli2.jsonc. Prudence avant tout : un tableau
// irrégulier (colonnes incohérentes, ligne sans pipe de tête…) est laissé
// intact — la porte le signalera. Usage : via `sh tools/markdown.sh fix`.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import stringWidth from "string-width";

const RACINE = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Préfixes de chemins à laisser hors du périmètre — À ADAPTER AU PROJET.
const EXCLUSIONS = ["node_modules/", "build/"];

function fichiersCibles() {
  return execFileSync(
    "git",
    ["ls-files", "--cached", "--others", "--exclude-standard"],
    { cwd: RACINE, encoding: "utf8" },
  )
    .split("\n")
    .filter((f) => f.endsWith(".md"))
    .filter((f) => !EXCLUSIONS.some((e) => f.startsWith(e)));
}

// Découpe une ligne de tableau en cellules sur les pipes NON échappés (`\|`
// reste littéral, le backslash est conservé). Renvoie null si la ligne ne
// commence pas par un pipe ou porte du contenu après le pipe final.
function cellules(ligne) {
  const t = ligne.trim();
  if (!t.startsWith("|")) return null;
  const cells = [];
  let cell = "";
  for (let i = 1; i < t.length; i++) {
    const c = t[i];
    if (c === "\\" && i + 1 < t.length) {
      cell += c + t[i + 1];
      i++;
    } else if (c === "|") {
      cells.push(cell.trim());
      cell = "";
    } else {
      cell += c;
    }
  }
  if (cell.trim() !== "") return null;
  return cells;
}

// Alignement déclaré par une cellule de séparateur (`---`, `:--`, `--:`, `:-:`),
// ou null si la cellule n'est pas un séparateur valide.
function alignement(cell) {
  if (!/^:?-+:?$/.test(cell)) return null;
  const g = cell.startsWith(":");
  const d = cell.endsWith(":");
  return g && d ? "centre" : g ? "gauche" : d ? "droite" : "aucun";
}

function celluleSeparateur(align, largeur) {
  if (align === "centre") return ":" + "-".repeat(largeur - 2) + ":";
  if (align === "gauche") return ":" + "-".repeat(largeur - 1);
  if (align === "droite") return "-".repeat(largeur - 1) + ":";
  return "-".repeat(largeur);
}

// Reformate un tableau (lignes brutes) ou renvoie null s'il est irrégulier.
function formaterTableau(lignes) {
  const rangs = lignes.map(cellules);
  if (rangs.some((r) => r === null)) return null;
  const nbCol = rangs[0].length;
  if (nbCol === 0 || rangs.some((r) => r.length !== nbCol)) return null;
  const aligns = rangs[1].map(alignement);
  if (aligns.some((a) => a === null)) return null;

  const largeurs = [];
  for (let c = 0; c < nbCol; c++) {
    let l = 3; // minimum pour `---` / `:-:`
    for (const [i, rang] of rangs.entries()) {
      if (i === 1) continue; // la ligne de séparateurs ne dicte pas la largeur
      l = Math.max(l, stringWidth(rang[c]));
    }
    largeurs.push(l);
  }

  const indent = lignes[0].match(/^ {0,3}/)[0];
  return rangs.map((rang, i) => {
    const cells = rang.map((cell, c) =>
      i === 1
        ? celluleSeparateur(aligns[c], largeurs[c])
        : cell + " ".repeat(largeurs[c] - stringWidth(cell)),
    );
    return indent + "| " + cells.join(" | ") + " |";
  });
}

// Repère les tableaux d'un document (hors blocs de code clôturés) et les
// reformate en place. Renvoie le texte normalisé.
function formaterDocument(texte) {
  const lignes = texte.split("\n");
  const sortie = [];
  let cloture = null; // marqueur de bloc de code ouvert (``` ou ~~~)
  for (let i = 0; i < lignes.length; i++) {
    const ligne = lignes[i];
    const fence = ligne.match(/^ {0,3}(`{3,}|~{3,})/);
    if (cloture) {
      if (fence && fence[1][0] === cloture[0] && fence[1].length >= cloture.length)
        cloture = null;
      sortie.push(ligne);
      continue;
    }
    if (fence) {
      cloture = fence[1];
      sortie.push(ligne);
      continue;
    }
    if (
      /^ {0,3}\|/.test(ligne) &&
      i + 1 < lignes.length &&
      /^ {0,3}\|[ :|-]+$/.test(lignes[i + 1]) &&
      lignes[i + 1].includes("-")
    ) {
      let fin = i + 2;
      while (fin < lignes.length && /^ {0,3}\|/.test(lignes[fin])) fin++;
      const bloc = lignes.slice(i, fin);
      const forme = formaterTableau(bloc);
      sortie.push(...(forme ?? bloc));
      i = fin - 1;
      continue;
    }
    sortie.push(ligne);
  }
  return sortie.join("\n");
}

let modifies = 0;
const fichiers = fichiersCibles();
for (const f of fichiers) {
  const chemin = resolve(RACINE, f);
  const avant = readFileSync(chemin, "utf8");
  const apres = formaterDocument(avant);
  if (apres !== avant) {
    writeFileSync(chemin, apres);
    modifies++;
    console.log(`  normalisé : ${f}`);
  }
}
console.log(
  `Tableaux : ${fichiers.length} fichier(s) examiné(s), ${modifies} normalisé(s).`,
);

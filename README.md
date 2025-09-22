# Algo Hermes - Trading Bot Crypto

**Date de création :** 22 septembre 2025
**Repository :** https://github.com/tradingluca31-boop/Hermes

## Objectif

L'algorithme **Hermes** est un bot de trading crypto basé sur une philosophie **momentum-following** pour les paires **BTC**, **ETH** et **SOL**. Il vise à capturer les mouvements directionnels significatifs tout en appliquant des filtres de risque stricts et une gestion de position optimisée.

### Caractéristiques clés
- **Ratio Risque/Récompense :** 1:5 (SL 0,70% / TP 3,5%)
- **Protection :** Break-even automatique à +1R
- **Fenêtre de trading :** 04:00 → 22:00 (Europe/Paris)
- **Filtrage intelligent :** Tendance H4, RSI, exposition, news économiques

## Règles d'entrée (Signaux)

Les **signaux** sont les déclencheurs d'entrée. **Tous les filtres actifs doivent être validés** pour qu'une position soit ouverte.

### 1. Mouvement H1 minimum
- **Condition :** Variation absolue de la bougie H1 ≥ `movement_threshold_h1` (défaut 0,50%)
- **Calcul :** |Close - Open| / Open × 100

### 2. Cross EMA21/55 (H1)
- **Long :** EMA21 croise au-dessus d'EMA55
- **Short :** EMA21 croise en-dessous d'EMA55

### 3. Cross SMMA50/200 (H1)
- **Long :** SMMA50 croise au-dessus de SMMA200
- **Short :** SMMA50 croise en-dessous de SMMA200

### 4. Momentum M15
- **Condition :** Variation d'une bougie M15 ≥ `m15_momentum_threshold` (défaut 0,50%)
- **Calcul :** (Close - Open) / Open × 100

## Filtres d'exclusion

Un seul filtre négatif **bloque l'entrée**. Tous les filtres sont évalués avant ouverture de position.

### 1. Tendance H4 (SMMA200)
- **Long uniquement :** si cours > SMMA200 H4
- **Short uniquement :** si cours < SMMA200 H4

### 2. RSI H4
- **Interdiction Long :** si RSI H4 ≥ `rsi_overbought_h4` (défaut 80)
- **Interdiction Short :** si RSI H4 ≤ `rsi_oversold_h4` (défaut 20)
- **Évaluation :** sur la dernière clôture H4

### 3. Exposition (2 interrupteurs indépendants)
- **`block_same_pair_on_off` :** Bloque si position déjà ouverte sur la même crypto
- **`block_other_crypto_on_off` :** Bloque si position ouverte sur une autre crypto

### 4. Fenêtre horaire
- **Interdiction :** 22:00 → 04:00 (Europe/Paris)
- **Autorisation :** 04:00 → 22:00 (Europe/Paris)

### 5. News économiques US
- **Événements surveillés :** CPI, PPI, NFP, FOMC, JOLTS, ADP, Taux de chômage
- **Blocage :** T−`news_block_minutes` à T+`news_block_minutes` (défaut 60 min)
- **Contrôle :** `news_filter_on_off` (ON/OFF)

## Gestion des positions

### Stop Loss & Take Profit
- **Stop Loss :** −0,70% du prix d'entrée
- **Take Profit :** +3,50% du prix d'entrée
- **Ratio R:R :** 1:5

### Break-Even
- **Déclenchement :** À +`be_trigger_pct` (défaut 0,70% = +1R)
- **Action :** Remonter le SL au prix d'entrée
- **Fréquence :** Une seule bascule (pas de reversion)

## Paramètres optimisables

| Paramètre | Valeur défaut | Type | Rôle |
|-----------|---------------|------|------|
| `stop_loss_pct` | 0.70% | % | Distance SL (prix d'entrée) |
| `take_profit_pct` | 3.50% | % | Distance TP (prix d'entrée) |
| `be_trigger_pct` | 0.70% | % | Seuil de passage BE (+1R) |
| `movement_threshold_h1` | 0.50% | % | Seuil signal "mouvement min." H1 |
| `m15_momentum_threshold` | 0.50% | % | Seuil signal momentum par bougie M15 |
| `rsi_overbought_h4` | 80 | valeur RSI | Filtre surachat H4 (interdit ≥ seuil) |
| `rsi_oversold_h4` | 20 | valeur RSI | Filtre survente H4 (interdit ≤ seuil) |
| `news_filter_on_off` | ON/OFF | bool | Active le filtre news US |
| `news_block_minutes` | 60 | minutes | Fenêtre d'exclusion autour de l'annonce |
| `block_same_pair_on_off` | ON/OFF | bool | Bloque si position ouverte sur même crypto |
| `block_other_crypto_on_off` | ON/OFF | bool | Bloque si position ouverte sur autre crypto |

## Journalisation

### Entrées de position
- **Timestamp :** Europe/Paris
- **Actif :** BTC/ETH/SOL
- **Sens :** Long/Short
- **Prix d'entrée :** Prix exact
- **Signaux validés :** Liste des signaux actifs

### Blocages
Motifs explicites avec codes :
- `FILTER_TREND_H4` : Tendance H4 contraire
- `FILTER_RSI_H4` : RSI H4 en zone extrême
- `FILTER_EXPO_SAME` : Position déjà ouverte sur même crypto
- `FILTER_EXPO_OTHER` : Position ouverte sur autre crypto
- `FILTER_HOURS` : Hors fenêtre horaire autorisée
- `FILTER_NEWS` : Fenêtre news active

**Données contextuelles :** Valeur RSI, état exposition, minutes avant/après news, heure locale

### Gestion de position
- **Passage BE :** Timestamp + prix de basculement
- **Hits SL/TP :** Timestamp + prix de sortie + résultat

## Conventions temporelles

**Toutes les règles temporelles** sont basées sur le fuseau **Europe/Paris** :
- Horaires de trading
- Calcul des fenêtres news
- Horodatage des logs
- Évaluation des bougies H4

## Architecture du projet

```
├── README.md                    # Spécification complète
├── config/
│   └── parameters.md           # Paramètres optimisables détaillés
├── docs/
│   └── logic.md               # Schéma décisionnel
├── tests/
│   └── plan_de_validation.md  # Check-list de validation
└── CHANGELOG.md               # Historique des versions
```

---

**Version :** 1.0
**Dernière mise à jour :** 22 septembre 2025
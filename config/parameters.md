# Paramètres Optimisables - Algo Hermes

**Date de création :** 22 septembre 2025

## Paramètres de gestion des risques

### Stop Loss & Take Profit

| Paramètre | Valeur défaut | Plage suggérée | Type | Description |
|-----------|---------------|----------------|------|-------------|
| `stop_loss_pct` | 0.70% | 0.50% - 1.50% | % | Distance du Stop Loss par rapport au prix d'entrée |
| `take_profit_pct` | 3.50% | 2.00% - 5.00% | % | Distance du Take Profit par rapport au prix d'entrée |
| `be_trigger_pct` | 0.70% | 0.50% - 1.50% | % | Seuil de déclenchement du Break-Even (+1R) |

**Notes :**
- Le ratio R:R est maintenu à 1:5 par défaut
- `be_trigger_pct` doit être ≤ `stop_loss_pct` pour cohérence
- Les valeurs sont testées sur historique 6 mois minimum

## Paramètres de signaux d'entrée

### Seuils de momentum

| Paramètre | Valeur défaut | Plage suggérée | Type | Description |
|-----------|---------------|----------------|------|-------------|
| `movement_threshold_h1` | 0.50% | 0.30% - 1.00% | % | Variation minimale d'une bougie H1 pour déclencher signal |
| `m15_momentum_threshold` | 0.50% | 0.30% - 1.00% | % | Variation minimale d'une bougie M15 pour signal momentum |

**Notes :**
- Valeurs plus basses = plus de signaux, mais plus de faux positifs
- Valeurs plus hautes = signaux plus fiables, mais moins fréquents
- Optimisation recommandée par paire (BTC/ETH/SOL)

## Paramètres de filtrage RSI

### Zones extrêmes H4

| Paramètre | Valeur défaut | Plage suggérée | Type | Description |
|-----------|---------------|----------------|------|-------------|
| `rsi_overbought_h4` | 80 | 70 - 85 | valeur RSI | Seuil de surachat H4 (bloque entrées Long ≥ seuil) |
| `rsi_oversold_h4` | 20 | 15 - 30 | valeur RSI | Seuil de survente H4 (bloque entrées Short ≤ seuil) |

**Notes :**
- RSI calculé sur période 14 par défaut
- Évaluation stricte à la clôture H4
- Adaptation possible selon volatilité crypto

## Paramètres de gestion des news

### Fenêtres d'exclusion

| Paramètre | Valeur défaut | Plage suggérée | Type | Description |
|-----------|---------------|----------------|------|-------------|
| `news_filter_on_off` | ON | ON/OFF | bool | Active/désactive le filtrage news économiques US |
| `news_block_minutes` | 60 | 30 - 120 | minutes | Durée de blocage avant et après annonce |

**News surveillées :**
- CPI (Consumer Price Index)
- PPI (Producer Price Index)
- NFP (Non-Farm Payrolls)
- FOMC (Federal Open Market Committee)
- JOLTS (Job Openings and Labor Turnover)
- ADP (Automatic Data Processing)
- Taux de chômage US

**Notes :**
- Horaires convertis automatiquement en Europe/Paris
- Impact majeur sur BTC/ETH/SOL observé historiquement
- Optimisation selon calendrier économique

## Paramètres d'exposition

### Contrôle des positions

| Paramètre | Valeur défaut | Options | Type | Description |
|-----------|---------------|---------|------|-------------|
| `block_same_pair_on_off` | ON | ON/OFF | bool | Bloque nouvelle position si déjà exposé sur même crypto |
| `block_other_crypto_on_off` | OFF | ON/OFF | bool | Bloque nouvelle position si exposé sur autre crypto |

**Stratégies d'exposition :**

### Configuration Conservative
- `block_same_pair_on_off` = ON
- `block_other_crypto_on_off` = ON
- **Résultat :** Maximum 1 position simultanée

### Configuration Équilibrée (défaut)
- `block_same_pair_on_off` = ON
- `block_other_crypto_on_off` = OFF
- **Résultat :** 1 position par crypto max (jusqu'à 3 simultanées)

### Configuration Agressive
- `block_same_pair_on_off` = OFF
- `block_other_crypto_on_off` = OFF
- **Résultat :** Positions multiples autorisées (gestion externe requise)

## Recommandations d'optimisation

### Phase 1 : Paramètres principaux
1. `movement_threshold_h1` : Tester 0.30%, 0.50%, 0.70%
2. `m15_momentum_threshold` : Tester 0.30%, 0.50%, 0.70%
3. `stop_loss_pct` / `take_profit_pct` : Maintenir ratio 1:5

### Phase 2 : Filtres RSI
1. `rsi_overbought_h4` : Tester 75, 80, 85
2. `rsi_oversold_h4` : Tester 15, 20, 25

### Phase 3 : Gestion exposition
1. Tester configurations Conservative/Équilibrée/Agressive
2. Analyser drawdown maximum et fréquence des trades

### Métriques de validation
- **Profit Factor** ≥ 1.5
- **Maximum Drawdown** ≤ 15%
- **Sharpe Ratio** ≥ 1.0
- **Nombre de trades** ≥ 100 (sur 6 mois)

---

**Dernière mise à jour :** 22 septembre 2025
**Prochaine révision :** Après backtests initiaux
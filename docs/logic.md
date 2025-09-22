# Logique Décisionnelle - Algo Hermes

**Date de création :** 22 septembre 2025

## Schéma de décision global

```
[NOUVELLE BOUGIE] → [ÉVALUATION SIGNAUX] → [ÉVALUATION FILTRES] → [DÉCISION ENTRÉE]
                                                ↓
[GESTION POSITION] ← [POSITION OUVERTE] ← [ENTRÉE VALIDÉE]
```

## Flux détaillé de décision

### Phase 1 : Détection des signaux

**Déclencheur :** Nouvelle bougie M15 ou H1

```
1. SIGNAL_MOVEMENT_H1
   ├── Calcul : |Close_H1 - Open_H1| / Open_H1 × 100
   ├── Condition : Résultat ≥ movement_threshold_h1
   └── État : ACTIF / INACTIF

2. SIGNAL_EMA_CROSS_H1
   ├── Calcul : Position relative EMA21 vs EMA55
   ├── Condition Long : EMA21 > EMA55 (nouveau croisement)
   ├── Condition Short : EMA21 < EMA55 (nouveau croisement)
   └── État : LONG / SHORT / NEUTRE

3. SIGNAL_SMMA_CROSS_H1
   ├── Calcul : Position relative SMMA50 vs SMMA200
   ├── Condition Long : SMMA50 > SMMA200 (nouveau croisement)
   ├── Condition Short : SMMA50 < SMMA200 (nouveau croisement)
   └── État : LONG / SHORT / NEUTRE

4. SIGNAL_MOMENTUM_M15
   ├── Calcul : (Close_M15 - Open_M15) / Open_M15 × 100
   ├── Condition : |Résultat| ≥ m15_momentum_threshold
   ├── Sens Long : Résultat > 0
   ├── Sens Short : Résultat < 0
   └── État : LONG / SHORT / INACTIF
```

**Synthèse des signaux :**
- **Signal d'entrée valide** si au moins UN signal est actif
- **Sens déterminé** par consensus des signaux directionnels

### Phase 2 : Évaluation des filtres

**Principe :** UN SEUL filtre négatif = BLOCAGE TOTAL

```
FILTER_TREND_H4
├── Calcul : Position prix vs SMMA200_H4
├── Long autorisé : Prix > SMMA200_H4
├── Short autorisé : Prix < SMMA200_H4
└── Résultat : PASS / BLOCK

FILTER_RSI_H4
├── Calcul : RSI_14 sur dernière clôture H4
├── Block Long : RSI ≥ rsi_overbought_h4
├── Block Short : RSI ≤ rsi_oversold_h4
└── Résultat : PASS / BLOCK

FILTER_EXPOSITION
├── Vérification positions existantes
├── Block si block_same_pair_on_off=ON ET position sur même crypto
├── Block si block_other_crypto_on_off=ON ET position sur autre crypto
└── Résultat : PASS / BLOCK

FILTER_HORAIRE
├── Heure actuelle (Europe/Paris)
├── Autorisé : 04:00 → 22:00
├── Interdit : 22:00 → 04:00
└── Résultat : PASS / BLOCK

FILTER_NEWS
├── Si news_filter_on_off = OFF → PASS automatique
├── Si news_filter_on_off = ON :
│   ├── Vérification calendrier news US
│   ├── Calcul fenêtre : T±news_block_minutes
│   └── Block si dans fenêtre active
└── Résultat : PASS / BLOCK
```

### Phase 3 : Décision d'entrée

```
DÉCISION FINALE
├── Si AUCUN signal actif → AUCUNE ACTION
├── Si AU MOINS UN filtre = BLOCK → LOG BLOCAGE + AUCUNE ACTION
└── Si TOUS filtres = PASS → OUVERTURE POSITION
    ├── Sens : Déterminé par signaux dominants
    ├── Prix d'entrée : Prix actuel du marché
    ├── Stop Loss : Prix d'entrée × (1 ± stop_loss_pct/100)
    ├── Take Profit : Prix d'entrée × (1 ± take_profit_pct/100)
    └── LOG ENTRÉE avec détails
```

## Gestion de position active

### Surveillance continue (chaque tick)

```
POSITION OUVERTE
├── Vérification Break-Even
│   ├── Condition : Profit unrealisé ≥ be_trigger_pct
│   ├── Action : Modifier SL au prix d'entrée
│   ├── État : BE_APPLIED (irréversible)
│   └── LOG Break-Even
├── Surveillance Stop Loss
│   ├── Condition : Prix atteint SL
│   ├── Action : Fermer position
│   └── LOG Sortie SL
└── Surveillance Take Profit
    ├── Condition : Prix atteint TP
    ├── Action : Fermer position
    └── LOG Sortie TP
```

## Cas particuliers et priorités

### Priorité des signaux
1. **Signal momentum M15** (réactivité maximale)
2. **Cross EMA21/55 H1** (tendance intermédiaire)
3. **Cross SMMA50/200 H1** (tendance principale)
4. **Movement H1** (volatilité suffisante)

### Gestion des conflits
- **Signaux contradictoires :** Priorité au signal le plus récent
- **Multiple cryptos :** Évaluation indépendante par paire
- **News simultanées :** Fenêtre étendue automatiquement

### États système
```
ÉTAT GLOBAL
├── STANDBY : Aucune position, surveillance active
├── POSITION_LONG : Position longue active
├── POSITION_SHORT : Position courte active
├── BLOCKED_HOURS : Hors fenêtre de trading
├── BLOCKED_NEWS : Fenêtre news active
└── BLOCKED_EXPO : Exposition maximale atteinte
```

## Séquence type d'exécution

### Exemple : Signal Long BTC

```
1. [08:30 UTC+2] Nouvelle bougie M15
2. SIGNAL_MOMENTUM_M15 = +0.65% → ACTIF (Long)
3. FILTER_TREND_H4 : BTC > SMMA200_H4 → PASS
4. FILTER_RSI_H4 : RSI = 55 → PASS
5. FILTER_EXPOSITION : Aucune position BTC → PASS
6. FILTER_HORAIRE : 08:30 dans [04:00-22:00] → PASS
7. FILTER_NEWS : Pas de news dans 60min → PASS
8. → OUVERTURE POSITION LONG BTC
9. SL à -0.70%, TP à +3.50%
10. Surveillance continue jusqu'à sortie
```

### Exemple : Blocage par RSI

```
1. [14:15 UTC+2] Cross EMA21/55 → Signal Long ETH
2. FILTER_TREND_H4 : ETH > SMMA200_H4 → PASS
3. FILTER_RSI_H4 : RSI = 82 → BLOCK (≥80)
4. → LOG "FILTER_RSI_H4: 82 ≥ 80" + AUCUNE ACTION
```

---

**Version :** 1.0
**Dernière mise à jour :** 22 septembre 2025
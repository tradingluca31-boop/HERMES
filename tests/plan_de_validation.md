# Plan de Validation - Algo Hermes

**Date de création :** 22 septembre 2025
**Version cible :** 1.0.0

## Objectif des tests

Valider le bon fonctionnement de tous les composants de l'algorithme Hermes avant déploiement en conditions réelles.

## 1. Tests unitaires des signaux

### 1.1 Signal Movement H1

**Cas de test :**
- [ ] **TEST_SIGNAL_H1_001** : Bougie H1 avec variation +0.60% → Signal ACTIF
- [ ] **TEST_SIGNAL_H1_002** : Bougie H1 avec variation -0.60% → Signal ACTIF
- [ ] **TEST_SIGNAL_H1_003** : Bougie H1 avec variation +0.30% → Signal INACTIF (< 0.50%)
- [ ] **TEST_SIGNAL_H1_004** : Bougie H1 avec variation 0.00% → Signal INACTIF
- [ ] **TEST_SIGNAL_H1_005** : Modification parameter movement_threshold_h1 = 1.00% → Mise à jour seuil

### 1.2 Signal Cross EMA21/55 H1

**Cas de test :**
- [ ] **TEST_EMA_CROSS_001** : EMA21 croise au-dessus EMA55 → Signal LONG
- [ ] **TEST_EMA_CROSS_002** : EMA21 croise en-dessous EMA55 → Signal SHORT
- [ ] **TEST_EMA_CROSS_003** : EMA21 = EMA55 (pas de croisement) → Signal NEUTRE
- [ ] **TEST_EMA_CROSS_004** : EMA21 reste au-dessus EMA55 → Signal NEUTRE (déjà croisé)

### 1.3 Signal Cross SMMA50/200 H1

**Cas de test :**
- [ ] **TEST_SMMA_CROSS_001** : SMMA50 croise au-dessus SMMA200 → Signal LONG
- [ ] **TEST_SMMA_CROSS_002** : SMMA50 croise en-dessous SMMA200 → Signal SHORT
- [ ] **TEST_SMMA_CROSS_003** : Pas de nouveau croisement → Signal NEUTRE

### 1.4 Signal Momentum M15

**Cas de test :**
- [ ] **TEST_MOMENTUM_001** : Bougie M15 +0.70% → Signal LONG
- [ ] **TEST_MOMENTUM_002** : Bougie M15 -0.70% → Signal SHORT
- [ ] **TEST_MOMENTUM_003** : Bougie M15 +0.30% → Signal INACTIF (< 0.50%)
- [ ] **TEST_MOMENTUM_004** : Bougie M15 doji (0.05%) → Signal INACTIF

## 2. Tests unitaires des filtres

### 2.1 Filtre Tendance H4

**Cas de test :**
- [ ] **TEST_TREND_H4_001** : Prix BTC > SMMA200_H4 + Signal Long → PASS
- [ ] **TEST_TREND_H4_002** : Prix BTC < SMMA200_H4 + Signal Long → BLOCK
- [ ] **TEST_TREND_H4_003** : Prix ETH < SMMA200_H4 + Signal Short → PASS
- [ ] **TEST_TREND_H4_004** : Prix ETH > SMMA200_H4 + Signal Short → BLOCK

### 2.2 Filtre RSI H4

**Cas de test :**
- [ ] **TEST_RSI_H4_001** : RSI = 85 + Signal Long → BLOCK (≥ 80)
- [ ] **TEST_RSI_H4_002** : RSI = 15 + Signal Short → BLOCK (≤ 20)
- [ ] **TEST_RSI_H4_003** : RSI = 55 + Signal Long → PASS
- [ ] **TEST_RSI_H4_004** : RSI = 55 + Signal Short → PASS
- [ ] **TEST_RSI_H4_005** : RSI = 80 exactement + Signal Long → BLOCK
- [ ] **TEST_RSI_H4_006** : RSI = 20 exactement + Signal Short → BLOCK

### 2.3 Filtre Exposition

**Cas de test :**
- [ ] **TEST_EXPO_001** : block_same_pair_on_off=ON + Position BTC existante + Signal BTC → BLOCK
- [ ] **TEST_EXPO_002** : block_same_pair_on_off=OFF + Position BTC existante + Signal BTC → PASS
- [ ] **TEST_EXPO_003** : block_other_crypto_on_off=ON + Position ETH + Signal BTC → BLOCK
- [ ] **TEST_EXPO_004** : block_other_crypto_on_off=OFF + Position ETH + Signal BTC → PASS
- [ ] **TEST_EXPO_005** : Aucune position + Tous signaux → PASS

### 2.4 Filtre Horaire

**Cas de test :**
- [ ] **TEST_HOURS_001** : 08:30 Europe/Paris → PASS
- [ ] **TEST_HOURS_002** : 23:30 Europe/Paris → BLOCK
- [ ] **TEST_HOURS_003** : 04:00 Europe/Paris exactement → PASS
- [ ] **TEST_HOURS_004** : 22:00 Europe/Paris exactement → BLOCK
- [ ] **TEST_HOURS_005** : 03:59 Europe/Paris → BLOCK

### 2.5 Filtre News

**Cas de test :**
- [ ] **TEST_NEWS_001** : news_filter_on_off=OFF → PASS (toujours)
- [ ] **TEST_NEWS_002** : CPI à 14:30 + Signal à 13:45 → BLOCK (45min avant)
- [ ] **TEST_NEWS_003** : NFP à 14:30 + Signal à 15:45 → BLOCK (75min après, avec 60min défaut)
- [ ] **TEST_NEWS_004** : Aucune news dans 2h + Signal → PASS
- [ ] **TEST_NEWS_005** : news_block_minutes=120 + News à 14:30 + Signal à 12:15 → BLOCK

## 3. Tests d'intégration

### 3.1 Scénarios d'entrée

**Cas de test :**
- [ ] **TEST_ENTRY_001** : Signal momentum M15 + Tous filtres PASS → OUVERTURE POSITION
- [ ] **TEST_ENTRY_002** : Multiple signaux + Un filtre BLOCK → AUCUNE ACTION
- [ ] **TEST_ENTRY_003** : Signaux contradictoires (Long+Short) → Priorité au plus récent
- [ ] **TEST_ENTRY_004** : Signal faible + RSI extrême → LOG BLOCAGE avec détails

### 3.2 Scénarios de gestion

**Cas de test :**
- [ ] **TEST_MGMT_001** : Position Long +0.70% → Break-Even activé
- [ ] **TEST_MGMT_002** : Position après BE + Prix retourne négatif → SL à prix d'entrée
- [ ] **TEST_MGMT_003** : Position atteint +3.50% → Fermeture TP
- [ ] **TEST_MGMT_004** : Position atteint -0.70% → Fermeture SL
- [ ] **TEST_MGMT_005** : BE activé puis nouveau signal même crypto → BLOCK si configuré

## 4. Tests de robustesse

### 4.1 Cas limites

**Cas de test :**
- [ ] **TEST_EDGE_001** : Gap de prix important (weekend) → Gestion appropriée
- [ ] **TEST_EDGE_002** : Volatilité extrême (>5% en M15) → Pas de sur-trading
- [ ] **TEST_EDGE_003** : RSI à exactement 80.0 → Comportement cohérent
- [ ] **TEST_EDGE_004** : News annulée dernière minute → Filtre adaptatif

### 4.2 Tests de performance

**Cas de test :**
- [ ] **TEST_PERF_001** : 1000 bougies M15 simulées < 1 seconde de traitement
- [ ] **TEST_PERF_002** : 3 cryptos simultanées → Pas d'interférence
- [ ] **TEST_PERF_003** : Calculs EMA/SMMA/RSI → Précision suffisante

## 5. Tests de logging

### 5.1 Logs d'entrée

**Cas de test :**
- [ ] **TEST_LOG_001** : Entrée Long BTC → Log complet avec timestamp, prix, signaux
- [ ] **TEST_LOG_002** : Format timestamp → Europe/Paris correct
- [ ] **TEST_LOG_003** : Signaux multiples → Tous listés dans log

### 5.2 Logs de blocage

**Cas de test :**
- [ ] **TEST_LOG_004** : Block RSI → "FILTER_RSI_H4: 82 ≥ 80"
- [ ] **TEST_LOG_005** : Block horaire → "FILTER_HOURS: 23:15 not in [04:00-22:00]"
- [ ] **TEST_LOG_006** : Block news → "FILTER_NEWS: CPI in 45min"

### 5.3 Logs de gestion

**Cas de test :**
- [ ] **TEST_LOG_007** : Break-Even → "BE_APPLIED: BTC at 45250.0"
- [ ] **TEST_LOG_008** : Stop Loss → "SL_HIT: BTC at 44850.0 (-0.70%)"
- [ ] **TEST_LOG_009** : Take Profit → "TP_HIT: BTC at 46750.0 (+3.50%)"

## 6. Tests de paramètres

### 6.1 Modification dynamique

**Cas de test :**
- [ ] **TEST_PARAM_001** : Modification stop_loss_pct → Nouvelles positions utilisent nouveau SL
- [ ] **TEST_PARAM_002** : Modification RSI seuils → Filtres mis à jour immédiatement
- [ ] **TEST_PARAM_003** : Paramètre invalide → Erreur + conservation ancienne valeur

## 7. Critères de validation

### 7.1 Critères obligatoires
- [ ] **100% des tests unitaires** passent
- [ ] **100% des tests d'intégration** passent
- [ ] **Logs complets et cohérents** pour tous les scénarios
- [ ] **Performance** : < 100ms par bougie en moyenne
- [ ] **Aucune position fantôme** (toutes les positions ont entrée + sortie)

### 7.2 Critères de qualité
- [ ] **Couverture de code** ≥ 95%
- [ ] **Documentation** synchronisée avec implémentation
- [ ] **Tests de régression** pour modifications futures

## 8. Protocole de test

### Phase 1 : Tests automatisés
1. Exécution de tous les tests unitaires
2. Validation logs automatique
3. Tests de performance

### Phase 2 : Tests manuels
1. Simulation avec données historiques réelles
2. Validation comportement pendant news
3. Test changement d'heure été/hiver

### Phase 3 : Validation finale
1. Backtest sur 6 mois de données
2. Vérification métriques attendues
3. Validation par équipe

---

**Responsable validation :** À définir
**Date limite :** Avant mise en production
**Prochaine révision :** Après chaque modification majeure
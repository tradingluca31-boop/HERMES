# Changelog - Algo Hermes

**Repository :** https://github.com/tradingluca31-boop/Hermes

Toutes les modifications notables de l'algorithme Hermes seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-09-22

### Ajouté (Added)
- **Spécification initiale** de l'algorithme Hermes
- **Support multi-crypto** : BTC, ETH, SOL
- **Système de signaux** :
  - Mouvement H1 minimum (0,50% par défaut)
  - Cross EMA21/55 sur H1
  - Cross SMMA50/200 sur H1
  - Momentum M15 (0,50% par défaut)
- **Système de filtres** :
  - Tendance H4 basée sur SMMA200
  - RSI H4 avec zones extrêmes (20-80)
  - Gestion exposition (même crypto / autres cryptos)
  - Fenêtre horaire (04:00-22:00 Europe/Paris)
  - Filtrage news économiques US
- **Gestion des positions** :
  - Stop Loss : 0,70%
  - Take Profit : 3,50% (ratio 1:5)
  - Break-even automatique à +1R
- **Journalisation complète** :
  - Logs d'entrée avec détails des signaux
  - Logs de blocage avec codes d'erreur
  - Logs de gestion (BE, SL, TP)
- **Documentation structurée** :
  - README.md avec spécification complète
  - config/parameters.md pour l'optimisation
  - docs/logic.md avec schéma décisionnel
  - tests/plan_de_validation.md pour les tests

### Configuration par défaut
```
stop_loss_pct = 0.70%
take_profit_pct = 3.50%
be_trigger_pct = 0.70%
movement_threshold_h1 = 0.50%
m15_momentum_threshold = 0.50%
rsi_overbought_h4 = 80
rsi_oversold_h4 = 20
news_filter_on_off = ON
news_block_minutes = 60
block_same_pair_on_off = ON
block_other_crypto_on_off = OFF
```

### Contraintes établies
- **Fuseau horaire** : Europe/Paris pour toutes les opérations
- **Évaluation RSI** : Strictement à la clôture H4
- **Logique filtres** : Un seul filtre négatif bloque l'entrée
- **Break-even** : Une seule bascule, pas de reversion
- **News surveillées** : CPI, PPI, NFP, FOMC, JOLTS, ADP, Chômage US

---

## Format des versions futures

### [X.Y.Z] - YYYY-MM-DD

#### Ajouté (Added)
- Nouvelles fonctionnalités

#### Modifié (Changed)
- Modifications de fonctionnalités existantes

#### Déprécié (Deprecated)
- Fonctionnalités bientôt supprimées

#### Supprimé (Removed)
- Fonctionnalités supprimées

#### Corrigé (Fixed)
- Corrections de bugs

#### Sécurité (Security)
- Corrections de vulnérabilités

---

## Types de modifications

### Versions majeures (X.0.0)
- Changements de logique fondamentale
- Modifications incompatibles avec versions antérieures
- Restructuration complète de l'algorithme

### Versions mineures (0.X.0)
- Ajout de nouvelles fonctionnalités
- Amélioration des filtres existants
- Nouveaux paramètres optimisables
- Compatibilité maintenue

### Versions de correction (0.0.X)
- Corrections de bugs
- Optimisations de performance
- Améliorations de logging
- Documentation mise à jour

---

**Prochaines évolutions prévues :**
- v1.1.0 : Implémentation et tests initiaux
- v1.2.0 : Optimisation des paramètres après backtests
- v1.3.0 : Intégration possible d'indicateurs additionnels
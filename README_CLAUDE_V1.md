# 🎯 BACKTEST ANALYZER CLAUDE V1

## Système de Backtesting Professionnel - Style Institutionnel

**Version:** 1.0  
**Auteur:** tradingluca31-boop  
**Type:** Trader quantitatif Wall Street Analytics  

---

## ✨ Fonctionnalités Principales

### 📊 **Métriques Complètes**
- **Toutes les métriques QuantStats** : CAGR, Sharpe, Sortino, Calmar, Max Drawdown
- **Métriques avancées** : Omega, VaR, CVaR, Recovery Factor, Skewness, Kurtosis
- **🎯 R/R Moyen par Trade** - Métrique personnalisée obligatoire
- **Profit Factor** et **Win Rate** détaillés

### 📈 **Visualisations Professionnelles**
- **Equity Curve** interactive avec benchmark optionnel
- **Drawdown Periods** avec zones de risque
- **Heatmap mensuelle** des rendements
- **Distribution des returns** avec statistiques

### 🎨 **Rapport HTML Institutionnel**
- Style professionnel type hedge fund
- Graphiques interactifs Plotly
- Export HTML complet
- Interface moderne et responsive

---

## 🚀 Installation Rapide

```bash
# Installer les dépendances
pip install -r requirements.txt

# Lancer l'application
streamlit run "BACK TEST CLAUDE V1.py"
```

---

## 📁 Format des Données

### **CSV Requis :**
```csv
Date,Returns
2023-01-01,0.012
2023-01-02,-0.005
2023-01-03,0.018
...
```

### **Types Supportés :**
1. **Returns** : Rendements quotidiens (0.01 = 1%)
2. **Equity** : Valeur du portefeuille (1000, 1050, etc.)
3. **Trades** : Détail des trades avec colonne PnL

---

## 🎯 Utilisation

1. **Upload** votre fichier CSV
2. **Sélectionner** le type de données
3. **Cliquer** "GÉNÉRER LE RAPPORT COMPLET"
4. **Télécharger** le rapport HTML professionnel

---

## 📋 Métriques Calculées

| Métrique | Description |
|----------|-------------|
| **CAGR** | Taux de croissance annuel composé |
| **Sharpe Ratio** | Rendement ajusté au risque |
| **Sortino Ratio** | Sharpe basé sur la downside deviation |
| **Max Drawdown** | Perte maximale depuis un pic |
| **🎯 R/R Moyen** | **Risk/Reward ratio moyen par trade** |
| **Profit Factor** | Gains totaux / Pertes totales |
| **Win Rate** | Pourcentage de trades gagnants |
| **VaR/CVaR** | Value at Risk et Conditional VaR |

---

## 🎨 Style Institutionnel

- **Design moderne** type Wall Street
- **Couleurs professionnelles** 
- **Graphiques interactifs**
- **Métriques mises en avant**
- **Export PDF/HTML**

---

## 🔧 Dépendances

- `pandas>=1.5.0` - Manipulation des données
- `quantstats>=0.0.62` - Métriques financières
- `plotly>=5.15.0` - Graphiques interactifs
- `streamlit>=1.25.0` - Interface web
- `numpy>=1.24.0` - Calculs numériques

---

## 📞 Support

Pour des questions ou améliorations, contactez **tradingluca31-boop** sur GitHub.

---

*🎯 "The best traders are the ones who measure everything" - Wall Street Wisdom*
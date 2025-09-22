# 📊 Analyseur d'Optimisations MQL5

Outil d'analyse et de tri des résultats d'optimisation MetaTrader 5. Transforme vos fichiers Excel d'optimisation en rapports détaillés avec statistiques avancées.

## 🎯 Fonctionnalités

- ✅ **Filtrage intelligent** : Sélectionne automatiquement les optimisations >7000€ profit avec <7% DD
- ✅ **Tri par variables** : Analyse RSI, SL, TP et toutes autres variables d'optimisation
- ✅ **Statistiques complètes** : Occurrences, profit min/moyen/max par variable
- ✅ **Top optimisations** : Classe les meilleures configurations
- ✅ **Rapports détaillés** : Export en format texte et JSON

## 🚀 Installation

1. **Cloner le dépôt** :
```bash
git clone https://github.com/[votre-username]/mql5-optimization-analyzer.git
cd mql5-optimization-analyzer
```

2. **Installer les dépendances** :
```bash
pip install pandas numpy openpyxl
```

## 📋 Utilisation

### Méthode Simple

1. Placez votre fichier Excel d'optimisation dans le dossier
2. Modifiez le nom du fichier dans `example_usage.py` :
```python
fichier_excel = "votre_fichier_optimisations.xlsx"  # ← Changez ici
```
3. Exécutez :
```bash
python example_usage.py
```

### Méthode Avancée

```python
from mql5_optimization_analyzer import MQL5OptimizationAnalyzer

# Créer l'analyseur
analyzer = MQL5OptimizationAnalyzer()

# Charger vos données
analyzer.load_excel_xml("mes_optimisations.xlsx")

# Filtrer (>7000€ profit, <7% DD)
analyzer.filter_profitable_optimizations(min_profit=7000, max_drawdown=7.0)

# Analyser les variables
analyzer.analyze_variables()

# Trouver le top 10
analyzer.find_best_optimizations(top_n=10)

# Générer les rapports
analyzer.generate_report("mon_rapport.txt")
analyzer.save_json_data("mes_donnees.json")
```

## 📊 Format de Fichier Supporté

L'analyseur accepte les fichiers Excel (.xlsx, .xls) ou XML exportés depuis MetaTrader 5.

**Colonnes détectées automatiquement** :
- Profit/Gain/Résultat
- Drawdown/DD/Perte
- Variables d'optimisation (RSI, SL, TP, etc.)

## 📈 Exemple de Sortie

```
📊 RÉSUMÉ GÉNÉRAL
----------------------------------------
• Total optimisations: 1000
• Optimisations profitables (>7000€, <7% DD): 45
• Taux de succès: 4.5%

🔍 ANALYSE PAR VARIABLES
----------------------------------------

🎯 RSI_Period
   • Valeurs uniques testées: 20
   • Profit minimum: 7012.50€
   • Profit maximum: 15420.80€
   • Profit moyen: 9850.30€
   • Top 5 valeurs:
     1. 14 → 12450.60€ (×3)
     2. 21 → 11230.40€ (×2)
     ...

🏆 TOP 10 MEILLEURES OPTIMISATIONS
----------------------------------------
#1 - Profit: 15420.80€
   RSI_Period: 14
   Stop_Loss: 50
   Take_Profit: 150
   ...
```

## 🔧 Configuration

Modifiez les paramètres dans `example_usage.py` :

```python
profit_minimum = 7000      # € minimum requis
drawdown_maximum = 7.0     # % DD maximum
top_optimisations = 15     # Nombre de top configs
```

## 📁 Fichiers Générés

- `rapport_optimisations.txt` - Rapport détaillé lisible
- `donnees_optimisations.json` - Données brutes pour analyse

## 🐛 Résolution de Problèmes

**Fichier non trouvé** : Vérifiez le chemin et le nom du fichier
**Colonnes non détectées** : Vérifiez que votre Excel contient les colonnes profit/drawdown
**Erreur de lecture** : Essayez de sauvegarder votre fichier Excel au format .xlsx

## 📞 Support

Pour toute question ou problème, créez une issue sur GitHub.

---
*Développé pour optimiser l'analyse des stratégies de trading MQL5* 🚀
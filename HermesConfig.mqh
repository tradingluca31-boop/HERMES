//+------------------------------------------------------------------+
//|                                                 HermesConfig.mqh |
//|                           Configuration Algo Hermes Trading Bot |
//|                      https://github.com/tradingluca31-boop/HERMES |
//+------------------------------------------------------------------+
#property copyright "tradingluca31-boop"
#property link      "https://github.com/tradingluca31-boop/HERMES"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Paramètres de gestion des risques                               |
//+------------------------------------------------------------------+
input group "=== GESTION DES RISQUES ==="
input double stop_loss_pct = 0.70;           // Stop Loss (%)
input double take_profit_pct = 3.50;         // Take Profit (%)
input double be_trigger_pct = 0.70;          // Seuil Break-Even (+1R) (%)

//+------------------------------------------------------------------+
//| Paramètres des signaux d'entrée                                 |
//+------------------------------------------------------------------+
input group "=== SIGNAUX D'ENTRÉE ==="
input double movement_threshold_h1 = 0.50;   // Seuil mouvement H1 (%)
input double m15_momentum_threshold = 0.50;  // Seuil momentum M15 (%)

//+------------------------------------------------------------------+
//| Paramètres des filtres RSI                                      |
//+------------------------------------------------------------------+
input group "=== FILTRES RSI H4 ==="
input int rsi_overbought_h4 = 80;           // RSI Surachat H4 (≥ bloque Long)
input int rsi_oversold_h4 = 20;             // RSI Survente H4 (≤ bloque Short)

//+------------------------------------------------------------------+
//| Paramètres de gestion des news                                  |
//+------------------------------------------------------------------+
input group "=== FILTRAGE NEWS US ==="
input bool news_filter_on_off = true;        // Active le filtre news US
input int news_block_minutes = 60;           // Fenêtre d'exclusion (minutes)

//+------------------------------------------------------------------+
//| Paramètres d'exposition                                         |
//+------------------------------------------------------------------+
input group "=== GESTION EXPOSITION ==="
input bool block_same_pair_on_off = true;    // Bloque si position sur même crypto
input bool block_other_crypto_on_off = false; // Bloque si position sur autre crypto

//+------------------------------------------------------------------+
//| Paramètres de trading                                           |
//+------------------------------------------------------------------+
input group "=== PARAMÈTRES TRADING ==="
input double risk_per_trade_pct = 1.0;      // Risque par trade (% du capital)
input int slippage_points = 10;              // Slippage autorisé (points)

//+------------------------------------------------------------------+
//| Constantes système                                              |
//+------------------------------------------------------------------+
#define HERMES_MAGIC 20250922                // Numéro magique HERMES
#define HERMES_VERSION "1.0.0"               // Version HERMES

//+------------------------------------------------------------------+
//| Structures de données                                           |
//+------------------------------------------------------------------+
struct SignalResult
{
    int signal_strength;        // Nombre de signaux actifs
    int direction;              // Direction: 1=Long, -1=Short, 0=Neutre
    string active_signals;      // Liste des signaux actifs
};

struct FilterResult
{
    bool all_passed;           // Tous les filtres passés
    string blocked_by;         // Nom du filtre qui bloque
    string context_data;       // Données contextuelles
};

struct NewsEvent
{
    datetime time;             // Heure de l'événement
    string name;               // Nom de l'événement
    int impact;                // Impact: 1=Faible, 2=Moyen, 3=Élevé
};

//+------------------------------------------------------------------+
//| Énumérations                                                     |
//+------------------------------------------------------------------+
enum ENUM_HERMES_SYMBOLS
{
    SYMBOL_BTCUSD,             // Bitcoin USD
    SYMBOL_ETHUSD,             // Ethereum USD
    SYMBOL_SOLUSD              // Solana USD
};

enum ENUM_SIGNAL_TYPE
{
    SIGNAL_MOVEMENT_H1,        // Mouvement H1 minimum
    SIGNAL_EMA_CROSS,          // Cross EMA21/55
    SIGNAL_SMMA_CROSS,         // Cross SMMA50/200
    SIGNAL_MOMENTUM_M15        // Momentum M15
};

enum ENUM_FILTER_TYPE
{
    FILTER_TREND_H4,           // Tendance H4 SMMA200
    FILTER_RSI_H4,             // RSI H4 zones extrêmes
    FILTER_EXPOSURE_SAME,      // Exposition même paire
    FILTER_EXPOSURE_OTHER,     // Exposition autres paires
    FILTER_HOURS,              // Fenêtre horaire
    FILTER_NEWS                // News économiques
};

//+------------------------------------------------------------------+
//| Variables globales de configuration                             |
//+------------------------------------------------------------------+
// Symboles supportés
string SUPPORTED_SYMBOLS[] = {"BTCUSD", "ETHUSD", "SOLUSD", "BTCEUR", "ETHEUR", "SOLEUR"};

// News économiques US importantes
string US_NEWS_EVENTS[] = {
    "CPI", "Consumer Price Index",
    "PPI", "Producer Price Index",
    "NFP", "Non-Farm Payrolls",
    "FOMC", "Federal Open Market Committee",
    "JOLTS", "Job Openings and Labor Turnover",
    "ADP", "ADP Employment",
    "Unemployment Rate", "Taux de chômage"
};

// Heures de trading (Europe/Paris)
const int TRADING_START_HOUR = 4;     // 04:00
const int TRADING_END_HOUR = 22;      // 22:00

//+------------------------------------------------------------------+
//| Validation des paramètres                                       |
//+------------------------------------------------------------------+
bool ValidateParameters()
{
    string errors = "";

    // Validation ratios
    if(stop_loss_pct <= 0 || stop_loss_pct > 10)
        errors += "Stop Loss doit être entre 0.1% et 10%\n";

    if(take_profit_pct <= 0 || take_profit_pct > 20)
        errors += "Take Profit doit être entre 0.1% et 20%\n";

    if(be_trigger_pct <= 0 || be_trigger_pct > stop_loss_pct)
        errors += "Break-Even doit être entre 0.1% et Stop Loss\n";

    // Validation seuils
    if(movement_threshold_h1 <= 0 || movement_threshold_h1 > 5)
        errors += "Seuil mouvement H1 doit être entre 0.1% et 5%\n";

    if(m15_momentum_threshold <= 0 || m15_momentum_threshold > 5)
        errors += "Seuil momentum M15 doit être entre 0.1% et 5%\n";

    // Validation RSI
    if(rsi_overbought_h4 <= 50 || rsi_overbought_h4 > 95)
        errors += "RSI surachat doit être entre 50 et 95\n";

    if(rsi_oversold_h4 < 5 || rsi_oversold_h4 >= 50)
        errors += "RSI survente doit être entre 5 et 50\n";

    if(rsi_oversold_h4 >= rsi_overbought_h4)
        errors += "RSI survente doit être < RSI surachat\n";

    // Validation news
    if(news_block_minutes < 0 || news_block_minutes > 300)
        errors += "Fenêtre news doit être entre 0 et 300 minutes\n";

    // Validation trading
    if(risk_per_trade_pct <= 0 || risk_per_trade_pct > 10)
        errors += "Risque par trade doit être entre 0.1% et 10%\n";

    if(errors != "")
    {
        Print("HERMES CONFIG ERROR:\n", errors);
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Affichage de la configuration                                   |
//+------------------------------------------------------------------+
void PrintConfiguration()
{
    Print("=== CONFIGURATION HERMES v", HERMES_VERSION, " ===");
    Print("Gestion des risques:");
    Print("  - Stop Loss: ", stop_loss_pct, "%");
    Print("  - Take Profit: ", take_profit_pct, "%");
    Print("  - Break-Even: ", be_trigger_pct, "%");
    Print("  - Ratio R:R: 1:", DoubleToString(take_profit_pct/stop_loss_pct, 1));

    Print("Signaux d'entrée:");
    Print("  - Mouvement H1: ", movement_threshold_h1, "%");
    Print("  - Momentum M15: ", m15_momentum_threshold, "%");

    Print("Filtres RSI H4:");
    Print("  - Surachat: ≥", rsi_overbought_h4);
    Print("  - Survente: ≤", rsi_oversold_h4);

    Print("Filtrage News:");
    Print("  - Actif: ", news_filter_on_off ? "OUI" : "NON");
    Print("  - Fenêtre: ±", news_block_minutes, " minutes");

    Print("Gestion exposition:");
    Print("  - Même crypto: ", block_same_pair_on_off ? "BLOQUÉ" : "AUTORISÉ");
    Print("  - Autres cryptos: ", block_other_crypto_on_off ? "BLOQUÉ" : "AUTORISÉ");

    Print("Trading:");
    Print("  - Risque/trade: ", risk_per_trade_pct, "%");
    Print("  - Slippage: ", slippage_points, " points");
    Print("======================================");
}

//+------------------------------------------------------------------+
//| Configuration des alertes                                       |
//+------------------------------------------------------------------+
input group "=== ALERTES & NOTIFICATIONS ==="
input bool enable_email_alerts = false;      // Envoyer emails
input bool enable_push_notifications = false; // Notifications push
input bool enable_sound_alerts = true;       // Alertes sonores

// Sons d'alerte
#define SOUND_ENTRY "tick.wav"               // Son d'entrée
#define SOUND_EXIT "stops.wav"               // Son de sortie
#define SOUND_BE "ok.wav"                    // Son break-even
#define SOUND_ERROR "timeout.wav"            // Son d'erreur

//+------------------------------------------------------------------+
//| Gestion des fuseaux horaires                                    |
//+------------------------------------------------------------------+
// Décalage Paris par rapport à GMT (en heures)
const int PARIS_GMT_OFFSET_WINTER = 1;      // Heure d'hiver
const int PARIS_GMT_OFFSET_SUMMER = 2;      // Heure d'été

// Dates de changement d'heure 2025 (exemple)
const datetime DST_START_2025 = D'2025.03.30 02:00';  // Dernier dimanche de mars
const datetime DST_END_2025 = D'2025.10.26 03:00';    // Dernier dimanche d'octobre
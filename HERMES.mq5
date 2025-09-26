//+------------------------------------------------------------------+
//|                                                       HERMES.MQ5 |
//|                                          Algo Hermes Trading Bot |
//|                      https://github.com/tradingluca31-boop/HERMES |
//+------------------------------------------------------------------+
#property copyright "tradingluca31-boop"
#property link      "https://github.com/tradingluca31-boop/HERMES"
#property version   "1.00"
#property description "Algorithme HERMES - Momentum Following pour BTC/ETH/SOL"
#property description "Date de création: 22 septembre 2025"
#property description "Ratio R:R 1:5 | SL 0.70% | TP 3.50% | Break-Even +1R"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Paramètres de l'algorithme HERMES                               |
//+------------------------------------------------------------------+

// Magic Number
#define HERMES_MAGIC 123456789

// Paramètres de risque
input double stop_loss_pct = 0.70;        // Stop Loss en %
input double take_profit_pct = 3.50;      // Take Profit en %
input double be_trigger_pct = 0.70;       // Break-Even trigger en %

// Paramètres RSI H4
input int rsi_oversold_h4 = 30;           // RSI H4 sur-vendu
input int rsi_overbought_h4 = 70;         // RSI H4 sur-acheté

// Filtres
input bool news_filter_on_off = true;           // Filtre News ON/OFF
input bool block_same_pair_on_off = true;       // Bloquer même paire
input bool block_other_crypto_on_off = true;    // Bloquer autres cryptos

// Paramètres de lot
input double risk_per_trade = 1.0;        // Risque par trade en %
input double min_lot_size = 0.01;         // Lot minimum
input double max_lot_size = 10.0;         // Lot maximum

// Paramètres horaires
input int start_hour = 8;                 // Heure de début (Europe/Paris)
input int end_hour = 22;                  // Heure de fin (Europe/Paris)

//+------------------------------------------------------------------+
//| Structures pour les signaux et filtres                          |
//+------------------------------------------------------------------+
struct SignalResult
{
    int signal_strength;     // Force du signal (0-4)
    int direction;          // Direction: 1=Long, -1=Short, 0=Neutre
    string active_signals;  // Liste des signaux actifs
};

struct FilterResult
{
    bool all_passed;        // Tous les filtres passés
    string blocked_by;      // Filtre qui bloque
    string context_data;    // Données contextuelles
};

// Symboles supportés
string supported_symbols[] = {"BTCUSD", "ETHUSD", "SOLUSD"};

//+------------------------------------------------------------------+
//| Fonction de validation des symboles                             |
//+------------------------------------------------------------------+
bool IsValidSymbol(string symbol)
{
    for(int i = 0; i < ArraySize(supported_symbols); i++)
    {
        if(StringFind(symbol, supported_symbols[i]) >= 0)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Fonction d'obtention de l'heure de Paris                        |
//+------------------------------------------------------------------+
datetime GetParisTime()
{
    return TimeCurrent();
}

//+------------------------------------------------------------------+
//| Fonction de calcul de la taille de lot                          |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    CAccountInfo account;
    double balance = account.Balance();
    double risk_amount = balance * risk_per_trade / 100.0;

    string current_symbol = Symbol();
    double price = SymbolInfoDouble(current_symbol, SYMBOL_ASK);
    double pip_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
    double stop_distance = price * stop_loss_pct / 100.0;

    double lot_size = risk_amount / (stop_distance / SymbolInfoDouble(current_symbol, SYMBOL_POINT) * pip_value);

    // Limites
    if(lot_size < min_lot_size) lot_size = min_lot_size;
    if(lot_size > max_lot_size) lot_size = max_lot_size;

    return NormalizeDouble(lot_size, 2);
}

//+------------------------------------------------------------------+
//| Initialisation du logging                                       |
//+------------------------------------------------------------------+
void InitializeLogging()
{
    string filename = "HERMES_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log";
    int log_handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
}

//+------------------------------------------------------------------+
//| Fonction de logging                                             |
//+------------------------------------------------------------------+
void LogMessage(string type, string message)
{
    int log_handle = FileOpen("HERMES_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log",
                             FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_READ);
    if(log_handle != INVALID_HANDLE)
    {
        FileSeek(log_handle, 0, SEEK_END);
        string log_entry = StringFormat("[%s] %s: %s\n",
                                      TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES),
                                      type,
                                      message);
        FileWrite(log_handle, log_entry);
        FileFlush(log_handle);
        FileClose(log_handle);
    }
}

//+------------------------------------------------------------------+
//| Fonction de mise à jour des données d'indicateurs               |
//+------------------------------------------------------------------+
bool UpdateIndicatorData()
{
    // Déclaration des variables
    extern int h1_ema21_handle, h1_ema55_handle;
    extern int h1_smma50_handle, h1_smma200_handle;
    extern int h4_smma200_handle, h4_rsi_handle;
    extern double h1_ema21[], h1_ema55[];
    extern double h1_smma50[], h1_smma200[];
    extern double h4_smma200[], h4_rsi[];

    // Copie des données
    if(CopyBuffer(h1_ema21_handle, 0, 0, 3, h1_ema21) <= 0) return false;
    if(CopyBuffer(h1_ema55_handle, 0, 0, 3, h1_ema55) <= 0) return false;
    if(CopyBuffer(h1_smma50_handle, 0, 0, 3, h1_smma50) <= 0) return false;
    if(CopyBuffer(h1_smma200_handle, 0, 0, 3, h1_smma200) <= 0) return false;
    if(CopyBuffer(h4_smma200_handle, 0, 0, 3, h4_smma200) <= 0) return false;
    if(CopyBuffer(h4_rsi_handle, 0, 0, 3, h4_rsi) <= 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Filtre horaire                                                  |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
    MqlDateTime time_struct;
    TimeToStruct(GetParisTime(), time_struct);
    int current_hour = time_struct.hour;

    return (current_hour >= start_hour && current_hour <= end_hour);
}

//+------------------------------------------------------------------+
//| Signal Movement H1                                              |
//+------------------------------------------------------------------+
bool CheckMovementH1Signal()
{
    extern double h1_ema21[], h1_ema55[];

    // Vérifie si les EMAs sont en mouvement ascendant ou descendant
    bool ema21_rising = h1_ema21[0] > h1_ema21[1];
    bool ema55_rising = h1_ema55[0] > h1_ema55[1];

    return (ema21_rising && ema55_rising) || (!ema21_rising && !ema55_rising);
}

//+------------------------------------------------------------------+
//| Signal Cross EMA21/55 H1                                        |
//+------------------------------------------------------------------+
int CheckEMACrossSignal()
{
    extern double h1_ema21[], h1_ema55[];

    bool cross_up = (h1_ema21[0] > h1_ema55[0] && h1_ema21[1] <= h1_ema55[1]);
    bool cross_down = (h1_ema21[0] < h1_ema55[0] && h1_ema21[1] >= h1_ema55[1]);

    if(cross_up) return 1;   // Long
    if(cross_down) return -1; // Short
    return 0;                // Pas de signal
}

//+------------------------------------------------------------------+
//| Signal Cross SMMA50/200 H1                                      |
//+------------------------------------------------------------------+
int CheckSMMACrossSignal()
{
    extern double h1_smma50[], h1_smma200[];

    bool cross_up = (h1_smma50[0] > h1_smma200[0] && h1_smma50[1] <= h1_smma200[1]);
    bool cross_down = (h1_smma50[0] < h1_smma200[0] && h1_smma50[1] >= h1_smma200[1]);

    if(cross_up) return 1;   // Long
    if(cross_down) return -1; // Short
    return 0;                // Pas de signal
}

//+------------------------------------------------------------------+
//| Signal Momentum M15                                             |
//+------------------------------------------------------------------+
int CheckMomentumM15Signal()
{
    string current_symbol = Symbol();
    double close_current = iClose(current_symbol, PERIOD_M15, 0);
    double close_previous = iClose(current_symbol, PERIOD_M15, 1);
    double close_2 = iClose(current_symbol, PERIOD_M15, 2);

    // Momentum basé sur 3 bougies consécutives
    if(close_current > close_previous && close_previous > close_2)
        return 1;  // Long
    if(close_current < close_previous && close_previous < close_2)
        return -1; // Short

    return 0; // Pas de signal
}

//+------------------------------------------------------------------+
//| Filtre Tendance H4                                              |
//+------------------------------------------------------------------+
bool CheckTrendH4Filter(int signal_direction)
{
    extern double h4_smma200[];
    string current_symbol = Symbol();
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    if(signal_direction > 0) // Long
        return current_price > h4_smma200[0];
    else if(signal_direction < 0) // Short
        return current_price < h4_smma200[0];

    return true;
}

//+------------------------------------------------------------------+
//| Filtre RSI H4                                                   |
//+------------------------------------------------------------------+
bool CheckRSIH4Filter(int signal_direction)
{
    extern double h4_rsi[];

    if(signal_direction > 0) // Long
        return h4_rsi[0] < rsi_overbought_h4;
    else if(signal_direction < 0) // Short
        return h4_rsi[0] > rsi_oversold_h4;

    return true;
}

//+------------------------------------------------------------------+
//| Filtre d'exposition                                             |
//+------------------------------------------------------------------+
string CheckExposureFilter()
{
    if(!block_same_pair_on_off && !block_other_crypto_on_off)
        return "";

    string current_symbol = Symbol();
    CPositionInfo position;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;

        string pos_symbol = position.Symbol();

        // Même paire
        if(block_same_pair_on_off && pos_symbol == current_symbol)
            return "FILTER_SAME_PAIR";

        // Autres cryptos
        if(block_other_crypto_on_off && pos_symbol != current_symbol)
        {
            for(int j = 0; j < ArraySize(supported_symbols); j++)
            {
                if(StringFind(pos_symbol, supported_symbols[j]) >= 0)
                    return "FILTER_OTHER_CRYPTO";
            }
        }
    }

    return "";
}

//+------------------------------------------------------------------+
//| Statut d'exposition                                             |
//+------------------------------------------------------------------+
string GetExposureStatus()
{
    int positions_count = 0;
    string positions_list = "";
    CPositionInfo position;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;

        positions_count++;
        positions_list += position.Symbol() + " ";
    }

    return StringFormat("Positions actives: %d [%s]", positions_count, positions_list);
}

//+------------------------------------------------------------------+
//| Filtre News (basique)                                           |
//+------------------------------------------------------------------+
string CheckNewsFilter()
{
    // Implémentation basique - peut être étendue
    MqlDateTime time_struct;
    TimeToStruct(GetParisTime(), time_struct);

    // Éviter les heures de news importantes (exemple: 14h30-15h30 Paris)
    if(time_struct.hour == 14 && time_struct.min >= 30)
        return "News économiques US";
    if(time_struct.hour == 15 && time_struct.min <= 30)
        return "News économiques US";

    return "";
}

//+------------------------------------------------------------------+
//| Gestion du Break-Even                                           |
//+------------------------------------------------------------------+
bool ShouldApplyBreakEven()
{
    extern bool be_applied;
    if(be_applied) return false;

    string current_symbol = Symbol();
    CPositionInfo position;
    if(!position.Select(current_symbol)) return false;

    double open_price = position.PriceOpen();
    double current_price = (position.PositionType() == POSITION_TYPE_BUY) ?
                          SymbolInfoDouble(current_symbol, SYMBOL_BID) :
                          SymbolInfoDouble(current_symbol, SYMBOL_ASK);

    double profit_pct = 0;
    if(position.PositionType() == POSITION_TYPE_BUY)
        profit_pct = (current_price - open_price) / open_price * 100.0;
    else
        profit_pct = (open_price - current_price) / open_price * 100.0;

    return profit_pct >= be_trigger_pct;
}

//+------------------------------------------------------------------+
//| Application du Break-Even                                       |
//+------------------------------------------------------------------+
bool ApplyBreakEven()
{
    string current_symbol = Symbol();
    CPositionInfo position;
    CTrade trade;

    if(!position.Select(current_symbol)) return false;

    double open_price = position.PriceOpen();

    if(trade.PositionModify(position.Ticket(), open_price, position.TakeProfit()))
    {
        string be_msg = StringFormat("Break-Even appliqué à %.5f", open_price);
        Print(be_msg);
        LogMessage("BREAK_EVEN", be_msg);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Logging des blocages                                            |
//+------------------------------------------------------------------+
void LogBlockage(SignalResult &signals, FilterResult &filters)
{
    string blockage_msg = StringFormat(
        "=== SIGNAL BLOQUÉ ===\n" +
        "Signaux: %s (Force: %d)\n" +
        "Direction: %s\n" +
        "Bloqué par: %s\n" +
        "Contexte: %s\n" +
        "Heure: %s",
        signals.active_signals,
        signals.signal_strength,
        (signals.direction > 0) ? "LONG" : (signals.direction < 0) ? "SHORT" : "NEUTRE",
        filters.blocked_by,
        filters.context_data,
        TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES)
    );

    LogMessage("BLOCKED", blockage_msg);
}

//+------------------------------------------------------------------+
//| Texte de la raison d'arrêt                                     |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM: return "Expert recompilé";
        case REASON_REMOVE: return "Expert retiré du graphique";
        case REASON_RECOMPILE: return "Expert recompilé";
        case REASON_CHARTCHANGE: return "Changement de graphique";
        case REASON_CHARTCLOSE: return "Graphique fermé";
        case REASON_PARAMETERS: return "Paramètres modifiés";
        case REASON_ACCOUNT: return "Compte changé";
        case REASON_TEMPLATE: return "Template appliqué";
        case REASON_INITFAILED: return "Échec d'initialisation";
        case REASON_CLOSE: return "Terminal fermé";
        default: return "Raison inconnue";
    }
}

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
CSymbolInfo symbol_info;
CAccountInfo account;

// Indicateurs
int h1_ema21_handle, h1_ema55_handle;
int h1_smma50_handle, h1_smma200_handle;
int h4_smma200_handle, h4_rsi_handle;

// Buffers des indicateurs
double h1_ema21[], h1_ema55[];
double h1_smma50[], h1_smma200[];
double h4_smma200[], h4_rsi[];

// Variables de gestion
bool be_applied = false;           // Break-even déjà appliqué
datetime last_signal_time = 0;    // Dernière évaluation de signal
string current_symbol = "";       // Symbole actuel

// Variables de logging
int log_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validation du symbole
    current_symbol = Symbol();
    if(!IsValidSymbol(current_symbol))
    {
        Print("HERMES ERROR: Symbole non supporté: ", current_symbol);
        Print("HERMES: Symboles supportés: BTCUSD, ETHUSD, SOLUSD");
        return INIT_FAILED;
    }

    // Configuration du trading
    trade.SetExpertMagicNumber(HERMES_MAGIC);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    // Initialisation des indicateurs H1
    h1_ema21_handle = iMA(current_symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema55_handle = iMA(current_symbol, PERIOD_H1, 55, 0, MODE_EMA, PRICE_CLOSE);
    h1_smma50_handle = iMA(current_symbol, PERIOD_H1, 50, 0, MODE_SMMA, PRICE_CLOSE);
    h1_smma200_handle = iMA(current_symbol, PERIOD_H1, 200, 0, MODE_SMMA, PRICE_CLOSE);

    // Initialisation des indicateurs H4
    h4_smma200_handle = iMA(current_symbol, PERIOD_H4, 200, 0, MODE_SMMA, PRICE_CLOSE);
    h4_rsi_handle = iRSI(current_symbol, PERIOD_H4, 14, PRICE_CLOSE);

    // Vérification des handles
    if(h1_ema21_handle == INVALID_HANDLE || h1_ema55_handle == INVALID_HANDLE ||
       h1_smma50_handle == INVALID_HANDLE || h1_smma200_handle == INVALID_HANDLE ||
       h4_smma200_handle == INVALID_HANDLE || h4_rsi_handle == INVALID_HANDLE)
    {
        Print("HERMES ERROR: Échec initialisation des indicateurs");
        return INIT_FAILED;
    }

    // Configuration des buffers
    ArraySetAsSeries(h1_ema21, true);
    ArraySetAsSeries(h1_ema55, true);
    ArraySetAsSeries(h1_smma50, true);
    ArraySetAsSeries(h1_smma200, true);
    ArraySetAsSeries(h4_smma200, true);
    ArraySetAsSeries(h4_rsi, true);

    // Initialisation du logging
    InitializeLogging();

    // Message de démarrage
    string start_msg = StringFormat(
        "=== HERMES v1.0.0 DÉMARRÉ ===\n" +
        "Symbole: %s\n" +
        "Heure: %s (Europe/Paris)\n" +
        "Paramètres: SL=%.2f%% | TP=%.2f%% | BE=%.2f%%\n" +
        "Filtres: RSI H4 [%d-%d] | News=%s | Expo_Same=%s | Expo_Other=%s",
        current_symbol,
        TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES),
        stop_loss_pct,
        take_profit_pct,
        be_trigger_pct,
        rsi_oversold_h4,
        rsi_overbought_h4,
        news_filter_on_off ? "ON" : "OFF",
        block_same_pair_on_off ? "ON" : "OFF",
        block_other_crypto_on_off ? "ON" : "OFF"
    );

    Print(start_msg);
    LogMessage("STARTUP", start_msg);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Libération des handles
    IndicatorRelease(h1_ema21_handle);
    IndicatorRelease(h1_ema55_handle);
    IndicatorRelease(h1_smma50_handle);
    IndicatorRelease(h1_smma200_handle);
    IndicatorRelease(h4_smma200_handle);
    IndicatorRelease(h4_rsi_handle);

    // Message d'arrêt
    string stop_msg = StringFormat(
        "=== HERMES ARRÊTÉ ===\n" +
        "Raison: %s\n" +
        "Heure: %s (Europe/Paris)",
        GetDeinitReasonText(reason),
        TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES)
    );

    Print(stop_msg);
    LogMessage("SHUTDOWN", stop_msg);

    // Fermeture du fichier de log
    if(log_handle != INVALID_HANDLE)
        FileClose(log_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérification des nouvelles bougies
    static datetime last_m15_time = 0;
    static datetime last_h1_time = 0;

    datetime current_m15_time = iTime(current_symbol, PERIOD_M15, 0);
    datetime current_h1_time = iTime(current_symbol, PERIOD_H1, 0);

    bool new_m15_candle = (current_m15_time != last_m15_time);
    bool new_h1_candle = (current_h1_time != last_h1_time);

    // Gestion des positions existantes (à chaque tick)
    ManageExistingPositions();

    // Évaluation des signaux seulement sur nouvelle bougie
    if(new_m15_candle || new_h1_candle)
    {
        last_m15_time = current_m15_time;
        last_h1_time = current_h1_time;

        // Mise à jour des données des indicateurs
        if(!UpdateIndicatorData())
        {
            LogMessage("ERROR", "Échec mise à jour des indicateurs");
            return;
        }

        // Évaluation des signaux et filtres
        EvaluateSignalsAndFilters();
    }
}

//+------------------------------------------------------------------+
//| Fonction d'évaluation des signaux et filtres                    |
//+------------------------------------------------------------------+
void EvaluateSignalsAndFilters()
{
    // Vérification filtre horaire d'abord
    if(!CheckTimeFilter())
    {
        return; // Pas de log pour filtre horaire (trop verbeux)
    }

    // Évaluation des signaux
    SignalResult signals = EvaluateSignals();

    // Si aucun signal, pas d'action
    if(signals.signal_strength == 0)
    {
        return;
    }

    // Évaluation des filtres
    FilterResult filters = EvaluateFilters(signals.direction);

    // Si un filtre bloque, log et arrêt
    if(!filters.all_passed)
    {
        LogBlockage(signals, filters);
        return;
    }

    // Tous les filtres passés - Ouverture de position
    OpenPosition(signals);
}

//+------------------------------------------------------------------+
//| Fonction d'évaluation des signaux                               |
//+------------------------------------------------------------------+
SignalResult EvaluateSignals()
{
    SignalResult result;
    result.signal_strength = 0;
    result.direction = 0;
    result.active_signals = "";

    // 1. Signal Movement H1
    if(CheckMovementH1Signal())
    {
        result.signal_strength++;
        result.active_signals += "MOVEMENT_H1 ";
    }

    // 2. Signal Cross EMA21/55 H1
    int ema_cross = CheckEMACrossSignal();
    if(ema_cross != 0)
    {
        result.signal_strength++;
        result.direction += ema_cross;
        result.active_signals += (ema_cross > 0) ? "EMA_CROSS_LONG " : "EMA_CROSS_SHORT ";
    }

    // 3. Signal Cross SMMA50/200 H1
    int smma_cross = CheckSMMACrossSignal();
    if(smma_cross != 0)
    {
        result.signal_strength++;
        result.direction += smma_cross;
        result.active_signals += (smma_cross > 0) ? "SMMA_CROSS_LONG " : "SMMA_CROSS_SHORT ";
    }

    // 4. Signal Momentum M15
    int momentum = CheckMomentumM15Signal();
    if(momentum != 0)
    {
        result.signal_strength++;
        result.direction += momentum;
        result.active_signals += (momentum > 0) ? "MOMENTUM_M15_LONG " : "MOMENTUM_M15_SHORT ";
    }

    // Détermination direction finale
    if(result.direction > 0)
        result.direction = 1;  // Long
    else if(result.direction < 0)
        result.direction = -1; // Short
    else
        result.direction = 0;  // Neutre

    return result;
}

//+------------------------------------------------------------------+
//| Fonction d'évaluation des filtres                               |
//+------------------------------------------------------------------+
FilterResult EvaluateFilters(int signal_direction)
{
    FilterResult result;
    result.all_passed = true;
    result.blocked_by = "";
    result.context_data = "";

    // 1. Filtre Tendance H4
    if(!CheckTrendH4Filter(signal_direction))
    {
        result.all_passed = false;
        result.blocked_by = "FILTER_TREND_H4";
        string current_symbol = Symbol();
        double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);
        extern double h4_smma200[];
        result.context_data = StringFormat("Prix=%.5f vs SMMA200_H4=%.5f",
                                         current_price, h4_smma200[0]);
        return result;
    }

    // 2. Filtre RSI H4
    if(!CheckRSIH4Filter(signal_direction))
    {
        result.all_passed = false;
        result.blocked_by = "FILTER_RSI_H4";
        extern double h4_rsi[];
        result.context_data = StringFormat("RSI_H4=%.1f | Seuils=[%d-%d]",
                                         h4_rsi[0], rsi_oversold_h4, rsi_overbought_h4);
        return result;
    }

    // 3. Filtre Exposition
    string expo_filter = CheckExposureFilter();
    if(expo_filter != "")
    {
        result.all_passed = false;
        result.blocked_by = expo_filter;
        result.context_data = GetExposureStatus();
        return result;
    }

    // 4. Filtre News (si activé)
    if(news_filter_on_off)
    {
        string news_filter = CheckNewsFilter();
        if(news_filter != "")
        {
            result.all_passed = false;
            result.blocked_by = "FILTER_NEWS";
            result.context_data = news_filter;
            return result;
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//| Fonction de gestion des positions existantes                    |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i))
            continue;

        if(position.Magic() != HERMES_MAGIC)
            continue;

        if(position.Symbol() != current_symbol)
            continue;

        // Gestion du Break-Even
        if(!be_applied && ShouldApplyBreakEven())
        {
            if(ApplyBreakEven())
            {
                be_applied = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fonction d'ouverture de position                                |
//+------------------------------------------------------------------+
void OpenPosition(SignalResult signals)
{
    double current_price = (signals.direction > 0) ?
                          SymbolInfoDouble(current_symbol, SYMBOL_ASK) :
                          SymbolInfoDouble(current_symbol, SYMBOL_BID);

    // Calcul des niveaux SL et TP
    double sl_price, tp_price;
    if(signals.direction > 0) // Long
    {
        sl_price = current_price * (1 - stop_loss_pct / 100.0);
        tp_price = current_price * (1 + take_profit_pct / 100.0);
    }
    else // Short
    {
        sl_price = current_price * (1 + stop_loss_pct / 100.0);
        tp_price = current_price * (1 - take_profit_pct / 100.0);
    }

    // Calcul du lot
    double lot_size = CalculateLotSize();

    // Ouverture de la position
    bool success = false;
    if(signals.direction > 0)
    {
        success = trade.Buy(lot_size, current_symbol, current_price, sl_price, tp_price,
                           "HERMES Long - " + signals.active_signals);
    }
    else
    {
        success = trade.Sell(lot_size, current_symbol, current_price, sl_price, tp_price,
                            "HERMES Short - " + signals.active_signals);
    }

    // Logging
    if(success)
    {
        be_applied = false; // Reset du break-even

        string entry_log = StringFormat(
            "=== POSITION OUVERTE ===\n" +
            "Symbole: %s\n" +
            "Direction: %s\n" +
            "Prix d'entrée: %.5f\n" +
            "Stop Loss: %.5f (%.2f%%)\n" +
            "Take Profit: %.5f (%.2f%%)\n" +
            "Lot: %.2f\n" +
            "Signaux actifs: %s\n" +
            "Heure: %s (Europe/Paris)",
            current_symbol,
            (signals.direction > 0) ? "LONG" : "SHORT",
            current_price,
            sl_price, stop_loss_pct,
            tp_price, take_profit_pct,
            lot_size,
            signals.active_signals,
            TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES)
        );

        Print(entry_log);
        LogMessage("ENTRY", entry_log);
    }
    else
    {
        string error_msg = StringFormat("ERREUR ouverture position: %d - %s",
                                      trade.ResultRetcode(), trade.ResultRetcodeDescription());
        Print(error_msg);
        LogMessage("ERROR", error_msg);
    }
}
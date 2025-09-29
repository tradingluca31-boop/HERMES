//+------------------------------------------------------------------+
//|                                                    HERMES_V2.MQ5 |
//|                              Algo Momentum Following BTC/ETH/SOL |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Paramètres de trading                                           |
//+------------------------------------------------------------------+
#define HERMES_MAGIC 987654321

// Gestion des risques
input double stop_loss_pct = 0.70;              // Stop Loss (%)
input double take_profit_pct = 3.50;            // Take Profit (%)
input double be_trigger_pct = 0.70;             // Break-Even trigger (%)

//=== INDICATEURS H1 - PÉRIODES ===
input int ema21_h1_period = 21;                 // EMA21 H1 période
input int ema55_h1_period = 55;                 // EMA55 H1 période
input int smma50_h1_period = 50;                // SMMA50 H1 période
input int smma200_h1_period = 200;              // SMMA200 H1 période
input int smma14_h1_period = 14;                // SMMA14 H1 période
input int smma28_h1_period = 28;                // SMMA28 H1 période

//=== CROSS INDICATEURS ===
input bool enable_ema21_55_cross = true;        // Activer cross EMA21/55
input bool enable_smma50_200_cross = true;      // Activer cross SMMA50/200
input bool enable_smma14_28_cross = true;       // Activer cross SMMA14/28
input int cross_confirmation_bars = 1;          // Barres confirmation cross
input double min_cross_separation = 0.05;      // Séparation minimum % pour cross valide

//=== INDICATEURS H4 ===
input int smma_filter_period = 200;             // SMMA H4 filtre période
input int rsi_h4_period = 14;                   // RSI H4 période

//=== SEUILS DE SIGNAUX ===
input double daily_volatility_threshold = 1.00;  // Volatilité Daily minimum (%) depuis 00h00 FR

//=== SYSTÈME DE VALIDATION ===
input int min_signals_required = 3;             // Minimum signaux requis (3/4)
input int signal_validity_hours = 3;            // Validité signal en heures
input double min_direction_consensus = 75.0;    // % minimum même direction (75% = 3/4 signaux)

//=== FILTRES RSI H4 ===
input int rsi_overbought_h4 = 80;               // RSI H4 sur-acheté
input int rsi_oversold_h4 = 20;                 // RSI H4 sur-vendu

// Filtres d'exposition
input bool block_same_pair_on_off = true;       // Bloquer même crypto
input bool block_other_crypto_on_off = true;    // Bloquer autres cryptos

// Filtre horaire (Europe/Paris)
input int trading_start_hour = 4;               // Début trading (04:00)
input int trading_end_hour = 22;                // Fin trading (22:00)

// Filtre news
input bool news_filter_on_off = true;           // Filtre news ON/OFF
input int news_block_minutes = 60;              // Minutes blocage news

// Paramètres lot
input double risk_per_trade = 1.0;              // Risque par trade (%)
input double min_lot_size = 0.01;               // Lot minimum
input double max_lot_size = 10.0;               // Lot maximum

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
CAccountInfo account;

// Indicateurs handles H1 - 3 CROSS
int h1_ema21_handle, h1_ema55_handle;           // Cross EMA21/55
int h1_smma50_handle, h1_smma200_handle;        // Cross SMMA50/200
int h1_smma14_handle, h1_smma28_handle;         // Cross SMMA14/28
// Indicateurs H4
int h4_smma200_handle, h4_rsi_handle;

// Buffers indicateurs H1 - 3 CROSS
double h1_ema21[], h1_ema55[];                  // Cross EMA21/55
double h1_smma50[], h1_smma200[];               // Cross SMMA50/200
double h1_smma14[], h1_smma28[];                // Cross SMMA14/28
// Buffers indicateurs H4
double h4_smma200[], h4_rsi[];


// Variables de gestion
bool be_applied = false;
string current_symbol = "";
int log_handle = INVALID_HANDLE;

// Système de suivi des 3 CROSS H1 + MOMENTUM
datetime last_ema21_55_cross_time = 0;          // Cross EMA21/55
datetime last_smma50_200_cross_time = 0;        // Cross SMMA50/200
datetime last_smma14_28_cross_time = 0;         // Cross SMMA14/28
datetime last_volatility_time = 0;              // Volatilité Daily
int last_ema21_55_direction = 0;
int last_smma50_200_direction = 0;
int last_smma14_28_direction = 0;
int last_volatility_direction = 0;

// Cryptos supportées
string supported_cryptos[] = {"BTCUSD", "ETHUSD", "SOLUSD"};

// News économiques US importantes
string major_news[] = {"CPI", "PPI", "NFP", "FOMC", "JOLTS", "ADP", "Unemployment"};

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                           |
//+------------------------------------------------------------------+
bool IsValidCrypto(string symbol)
{
    for(int i = 0; i < ArraySize(supported_cryptos); i++)
    {
        if(StringFind(symbol, supported_cryptos[i]) >= 0)
            return true;
    }
    return false;
}

datetime GetParisTime()
{
    // Simulation fuseau Europe/Paris (UTC+1/+2)
    return TimeCurrent() + 3600; // Simplification UTC+1
}

double CalculateLotSize()
{
    double balance = account.Balance();
    double risk_amount = balance * risk_per_trade / 100.0;
    double price = SymbolInfoDouble(current_symbol, SYMBOL_ASK);
    double pip_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
    double stop_distance = price * stop_loss_pct / 100.0;

    double lot_size = risk_amount / (stop_distance / SymbolInfoDouble(current_symbol, SYMBOL_POINT) * pip_value);

    if(lot_size < min_lot_size) lot_size = min_lot_size;
    if(lot_size > max_lot_size) lot_size = max_lot_size;

    return NormalizeDouble(lot_size, 2);
}

void LogEntry(string message)
{
    if(log_handle == INVALID_HANDLE)
    {
        string filename = "HERMES_V2_" + current_symbol + "_" + TimeToString(GetParisTime(), TIME_DATE) + ".log";
        log_handle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_READ);
    }

    if(log_handle != INVALID_HANDLE)
    {
        FileSeek(log_handle, 0, SEEK_END);
        string timestamp = TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES);
        string log_line = StringFormat("[%s] %s\n", timestamp, message);
        FileWrite(log_handle, log_line);
        FileFlush(log_handle);
    }
}

bool UpdateIndicatorData()
{
    // Indicateurs H1
    if(CopyBuffer(h1_ema21_handle, 0, 0, 3, h1_ema21) <= 0) return false;
    if(CopyBuffer(h1_ema55_handle, 0, 0, 3, h1_ema55) <= 0) return false;
    if(CopyBuffer(h1_smma50_handle, 0, 0, 3, h1_smma50) <= 0) return false;
    if(CopyBuffer(h1_smma200_handle, 0, 0, 3, h1_smma200) <= 0) return false;

    // Indicateurs H4
    if(CopyBuffer(h4_smma200_handle, 0, 0, 3, h4_smma200) <= 0) return false;
    if(CopyBuffer(h4_rsi_handle, 0, 0, 3, h4_rsi) <= 0) return false;

    // Nouveaux indicateurs H1
    if(CopyBuffer(h1_smma14_handle, 0, 0, 3, h1_smma14) <= 0) return false;
    if(CopyBuffer(h1_smma28_handle, 0, 0, 3, h1_smma28) <= 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| SIGNAUX D'ENTRÉE AVEC SUIVI FLEXIBLE (5 SIGNAUX)              |
//+------------------------------------------------------------------+

// 1. Cross EMA21/55 H1 (EMA21 guide la dynamique)
void CheckEMA21_55_Cross()
{
    if(!enable_ema21_55_cross) return;

    // Vérification séparation minimum
    double separation_pct = MathAbs(h1_ema21[0] - h1_ema55[0]) / h1_ema55[0] * 100.0;
    if(separation_pct < min_cross_separation) return;

    // Détection du cross
    int current_cross = 0;

    // Long: EMA21 croise au-dessus d'EMA55
    if(h1_ema21[0] > h1_ema55[0] && h1_ema21[1] <= h1_ema55[1])
        current_cross = 1;

    // Short: EMA21 croise en-dessous d'EMA55
    else if(h1_ema21[0] < h1_ema55[0] && h1_ema21[1] >= h1_ema55[1])
        current_cross = -1;

    if(current_cross != 0)
    {
        last_ema21_55_direction = current_cross;
        last_ema21_55_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: EMA21/55 CROSS " + direction + " - Séparation: " + DoubleToString(separation_pct, 2) + "%");
    }
}

// 2. Cross SMMA50/200 H1 (SMMA50 guide le trend - suit mieux le prix)
void CheckSMMA50_200_Cross()
{
    if(!enable_smma50_200_cross) return;

    // Vérification séparation minimum
    double separation_pct = MathAbs(h1_smma50[0] - h1_smma200[0]) / h1_smma200[0] * 100.0;
    if(separation_pct < min_cross_separation) return;

    // Détection du cross
    int current_cross = 0;

    // Long: SMMA50 croise au-dessus de SMMA200
    if(h1_smma50[0] > h1_smma200[0] && h1_smma50[1] <= h1_smma200[1])
        current_cross = 1;

    // Short: SMMA50 croise en-dessous de SMMA200
    else if(h1_smma50[0] < h1_smma200[0] && h1_smma50[1] >= h1_smma200[1])
        current_cross = -1;

    if(current_cross != 0)
    {
        last_smma50_200_direction = current_cross;
        last_smma50_200_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: SMMA50/200 CROSS " + direction + " - Séparation: " + DoubleToString(separation_pct, 2) + "%");
    }
}

// 3. Volatilité Daily depuis 00h00 heure française
void CheckDailyVolatility()
{
    // Obtenir l'heure de Paris courante
    MqlDateTime paris_time;
    TimeToStruct(GetParisTime(), paris_time);

    // Calculer l'heure 00h00 du jour en cours (heure française)
    datetime today_start_fr = GetParisTime() - (paris_time.hour * 3600 + paris_time.min * 60 + paris_time.sec);

    // Trouver l'index de la bougie Daily courante
    int daily_shift = iBarShift(current_symbol, PERIOD_D1, today_start_fr);
    if(daily_shift < 0) daily_shift = 0;

    // Prix d'ouverture Daily à 00h00 heure française
    double daily_open = iOpen(current_symbol, PERIOD_D1, daily_shift);
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    // Calcul de la volatilité en % depuis 00h00 FR
    double volatility_pct = (current_price - daily_open) / daily_open * 100.0;

    // Vérifier si la volatilité dépasse le seuil minimum (1%)
    if(MathAbs(volatility_pct) >= daily_volatility_threshold)
    {
        last_volatility_direction = volatility_pct > 0 ? 1 : -1;  // +1% = LONG, -1% = SHORT
        last_volatility_time = GetParisTime();
        string direction = last_volatility_direction > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: VOLATILITÉ_DAILY " + direction + " - " + DoubleToString(volatility_pct, 2) + "% depuis 00h00 FR (Prix ouv=" + DoubleToString(daily_open, 5) + ", Prix actuel=" + DoubleToString(current_price, 5) + ")");
    }
}


// 4. Cross SMMA14/28 H1 (micro-trend H1)
void CheckSMMA14_28_Cross()
{
    if(!enable_smma14_28_cross) return;

    // Vérification séparation minimum
    double separation_pct = MathAbs(h1_smma14[0] - h1_smma28[0]) / h1_smma28[0] * 100.0;
    if(separation_pct < min_cross_separation) return;

    // Détection du cross H1 micro-trend
    int current_cross = 0;

    // Long: SMMA14 croise au-dessus de SMMA28
    if(h1_smma14[0] > h1_smma28[0] && h1_smma14[1] <= h1_smma28[1])
        current_cross = 1;

    // Short: SMMA14 croise en-dessous de SMMA28
    else if(h1_smma14[0] < h1_smma28[0] && h1_smma14[1] >= h1_smma28[1])
        current_cross = -1;

    if(current_cross != 0)
    {
        last_smma14_28_direction = current_cross;
        last_smma14_28_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: SMMA14/28 CROSS " + direction + " - Séparation: " + DoubleToString(separation_pct, 2) + "%");
    }
}

//+------------------------------------------------------------------+
//| VALIDATION FLEXIBLE DES SIGNAUX                                 |
//+------------------------------------------------------------------+
bool IsSignalStillValid(datetime signal_time)
{
    if(signal_time == 0) return false;

    datetime current_time = GetParisTime();
    int hours_elapsed = (int)((current_time - signal_time) / 3600);

    return hours_elapsed <= signal_validity_hours;
}

bool IsEMA21_55_DirectionValid()
{
    if(!enable_ema21_55_cross) return false;
    if(!IsSignalStillValid(last_ema21_55_cross_time)) return false;

    // Vérification que EMA21 suit toujours la direction
    if(last_ema21_55_direction > 0)
        return h1_ema21[0] > h1_ema55[0];  // EMA21 toujours au-dessus
    else if(last_ema21_55_direction < 0)
        return h1_ema21[0] < h1_ema55[0];  // EMA21 toujours en-dessous

    return false;
}

bool IsSMMA50_200_DirectionValid()
{
    if(!enable_smma50_200_cross) return false;
    if(!IsSignalStillValid(last_smma50_200_cross_time)) return false;

    // Vérification que SMMA50 suit toujours la direction
    if(last_smma50_200_direction > 0)
        return h1_smma50[0] > h1_smma200[0];  // SMMA50 toujours au-dessus
    else if(last_smma50_200_direction < 0)
        return h1_smma50[0] < h1_smma200[0];  // SMMA50 toujours en-dessous

    return false;
}


bool IsVolatilityValid()
{
    if(!IsSignalStillValid(last_volatility_time) || last_volatility_direction == 0) return false;

    // Recalcul de la volatilité actuelle depuis 00h00 FR
    MqlDateTime paris_time;
    TimeToStruct(GetParisTime(), paris_time);
    datetime today_start_fr = GetParisTime() - (paris_time.hour * 3600 + paris_time.min * 60 + paris_time.sec);

    int daily_shift = iBarShift(current_symbol, PERIOD_D1, today_start_fr);
    if(daily_shift < 0) daily_shift = 0;

    double daily_open = iOpen(current_symbol, PERIOD_D1, daily_shift);
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);
    double current_volatility_pct = (current_price - daily_open) / daily_open * 100.0;

    // La volatilité doit être dans la même direction ET suffisante
    if(last_volatility_direction > 0)
        return current_volatility_pct >= daily_volatility_threshold;
    else
        return current_volatility_pct <= -daily_volatility_threshold;
}

bool IsSMMA14_28_DirectionValid()
{
    if(!enable_smma14_28_cross) return false;
    if(!IsSignalStillValid(last_smma14_28_cross_time)) return false;

    // Vérification que SMMA14 H1 suit toujours la direction
    if(last_smma14_28_direction > 0)
        return h1_smma14[0] > h1_smma28[0];  // SMMA14 toujours au-dessus
    else if(last_smma14_28_direction < 0)
        return h1_smma14[0] < h1_smma28[0];  // SMMA14 toujours en-dessous

    return false;
}

//+------------------------------------------------------------------+
//| FILTRES D'EXCLUSION                                             |
//+------------------------------------------------------------------+

// 1. Tendance H4 (SMMA variable - plus souple)
bool CheckTrendH4Filter(int direction)
{
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    if(direction > 0) // Long uniquement si cours > SMMA H4
        return current_price > h4_smma200[0];  // Utilise la SMMA configurable
    else if(direction < 0) // Short uniquement si cours < SMMA H4
        return current_price < h4_smma200[0];  // Utilise la SMMA configurable

    return true;
}

// 2. RSI H4
string CheckRSIH4Filter(int direction)
{
    double current_rsi = h4_rsi[0];

    if(direction > 0 && current_rsi >= rsi_overbought_h4)
        return "FILTER_RSI_H4";

    if(direction < 0 && current_rsi <= rsi_oversold_h4)
        return "FILTER_RSI_H4";

    return "";
}

// 3. Exposition
string CheckExposureFilter()
{
    // Log pour debug
    LogEntry("DEBUG: Vérification exposition - Positions totales: " + IntegerToString(PositionsTotal()));

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;

        // Log des détails de chaque position
        string pos_symbol = position.Symbol();
        ulong pos_magic = position.Magic();

        LogEntry("DEBUG: Position " + IntegerToString(i) + " - Symbole: " + pos_symbol + " - Magic: " + IntegerToString(pos_magic) + " - HERMES_MAGIC: " + IntegerToString(HERMES_MAGIC));

        // CORRECTION IMPORTANTE: Vérifier TOUTES les positions, pas seulement celles avec notre Magic
        // Car on veut éviter de trader si on a déjà des positions ouvertes (même d'autres EAs)

        // Même crypto (vérifier TOUTES les positions sur le même symbole)
        if(block_same_pair_on_off && pos_symbol == current_symbol)
        {
            LogEntry("BLOCAGE EXPOSITION: Position existante sur " + current_symbol + " détectée (Magic: " + IntegerToString(pos_magic) + ")");
            return "FILTER_EXPO_SAME";
        }

        // Autre crypto (vérifier seulement nos positions HERMES)
        if(block_other_crypto_on_off && position.Magic() == HERMES_MAGIC && pos_symbol != current_symbol)
        {
            for(int j = 0; j < ArraySize(supported_cryptos); j++)
            {
                if(StringFind(pos_symbol, supported_cryptos[j]) >= 0)
                {
                    LogEntry("BLOCAGE EXPOSITION: Position HERMES existante sur autre crypto " + pos_symbol);
                    return "FILTER_EXPO_OTHER";
                }
            }
        }
    }

    LogEntry("DEBUG: Aucune exposition détectée - Ouverture autorisée");
    return "";
}

// 4. Fenêtre horaire
string CheckTimeFilter()
{
    MqlDateTime paris_time;
    TimeToStruct(GetParisTime(), paris_time);
    int current_hour = paris_time.hour;

    // Interdiction 22:00 → 04:00
    if(current_hour >= trading_end_hour || current_hour < trading_start_hour)
        return "FILTER_HOURS";

    return "";
}

// 5. News économiques US
string CheckNewsFilter()
{
    if(!news_filter_on_off) return "";

    // Simulation basique - à améliorer avec calendrier économique réel
    MqlDateTime paris_time;
    TimeToStruct(GetParisTime(), paris_time);

    // Blocage exemple: 14:30-15:30 Paris (news US typiques)
    if(paris_time.hour == 14 && paris_time.min >= 30)
        return "FILTER_NEWS";
    if(paris_time.hour == 15 && paris_time.min <= 30)
        return "FILTER_NEWS";

    return "";
}

//+------------------------------------------------------------------+
//| ÉVALUATION FLEXIBLE DES SIGNAUX                                 |
//+------------------------------------------------------------------+
string EvaluateEntry()
{
    // Mise à jour des 3 CROSS H1 + VOLATILITÉ DAILY
    CheckEMA21_55_Cross();          // Cross EMA21/55
    CheckSMMA50_200_Cross();        // Cross SMMA50/200
    CheckSMMA14_28_Cross();         // Cross SMMA14/28
    CheckDailyVolatility();         // Volatilité Daily depuis 00h00 FR

    // Vérification des signaux valides actuellement (4 signaux: 3 cross H1 + volatilité daily)
    bool ema21_55_valid = IsEMA21_55_DirectionValid();
    bool smma50_200_valid = IsSMMA50_200_DirectionValid();
    bool smma14_28_valid = IsSMMA14_28_DirectionValid();
    bool volatility_valid = IsVolatilityValid();

    // Comptage des signaux actifs (4 signaux total: 3 cross H1 + volatilité daily)
    int active_signals_count = 0;
    int direction_sum = 0;
    string active_signals = "";

    if(ema21_55_valid)
    {
        active_signals_count++;
        direction_sum += last_ema21_55_direction;
        active_signals += last_ema21_55_direction > 0 ? "EMA21/55_LONG " : "EMA21/55_SHORT ";
    }

    if(smma50_200_valid)
    {
        active_signals_count++;
        direction_sum += last_smma50_200_direction;
        active_signals += last_smma50_200_direction > 0 ? "SMMA50/200_LONG " : "SMMA50/200_SHORT ";
    }

    if(smma14_28_valid)
    {
        active_signals_count++;
        direction_sum += last_smma14_28_direction;
        active_signals += last_smma14_28_direction > 0 ? "SMMA14/28_LONG " : "SMMA14/28_SHORT ";
    }

    if(volatility_valid)
    {
        active_signals_count++;
        direction_sum += last_volatility_direction;
        active_signals += last_volatility_direction > 0 ? "VOLATILITÉ_DAILY_LONG " : "VOLATILITÉ_DAILY_SHORT ";
    }

    // Vérification minimum de signaux requis (4 signaux: 3 cross H1 + volatilité daily)
    if(active_signals_count < min_signals_required)
    {
        if(active_signals_count > 0)
        {
            LogEntry("SIGNAUX INSUFFISANTS: " + IntegerToString(active_signals_count) + "/4 (min " + IntegerToString(min_signals_required) + ") - Signaux: " + active_signals);
        }
        return "";
    }

    // LOGIQUE STRICTE: Détermination direction finale
    // Au lieu d'une simple somme, on exige une direction majoritaire claire
    int long_signals = 0;
    int short_signals = 0;

    if(ema21_55_valid) last_ema21_55_direction > 0 ? long_signals++ : short_signals++;
    if(smma50_200_valid) last_smma50_200_direction > 0 ? long_signals++ : short_signals++;
    if(smma14_28_valid) last_smma14_28_direction > 0 ? long_signals++ : short_signals++;
    if(volatility_valid) last_volatility_direction > 0 ? long_signals++ : short_signals++;

    // Exiger une majorité claire (configurable, par défaut 75%)
    int total_directional_signals = long_signals + short_signals;
    double long_percentage = (double)long_signals / total_directional_signals * 100.0;
    double short_percentage = (double)short_signals / total_directional_signals * 100.0;

    int final_direction = 0;
    if(long_percentage >= min_direction_consensus) final_direction = 1;
    else if(short_percentage >= min_direction_consensus) final_direction = -1;

    if(final_direction == 0)
    {
        LogEntry("DIRECTION INDÉTERMINÉE: Signaux contradictoires - Long:" + IntegerToString(long_signals) + " Short:" + IntegerToString(short_signals) + " - " + active_signals);
        return "";
    }

    LogEntry("SIGNAUX VALIDÉS: " + IntegerToString(active_signals_count) + "/4 - Direction: " + (final_direction > 0 ? "LONG" : "SHORT") +
             " (" + DoubleToString(final_direction > 0 ? long_percentage : short_percentage, 1) + "% consensus) - " + active_signals);

    // Vérification de tous les filtres
    if(!CheckTrendH4Filter(final_direction))
    {
        LogEntry("BLOCAGE: FILTER_TREND_H4 - Prix=" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_BID), 5) +
                " vs SMMA" + IntegerToString(smma_filter_period) + "_H4=" + DoubleToString(h4_smma200[0], 5));
        return "";
    }

    string rsi_filter = CheckRSIH4Filter(final_direction);
    if(rsi_filter != "")
    {
        LogEntry("BLOCAGE: " + rsi_filter + " - RSI_H4=" + DoubleToString(h4_rsi[0], 1) +
                " Seuils=[" + IntegerToString(rsi_oversold_h4) + "-" + IntegerToString(rsi_overbought_h4) + "]");
        return "";
    }

    string expo_filter = CheckExposureFilter();
    if(expo_filter != "")
    {
        LogEntry("BLOCAGE: " + expo_filter + " - Exposition=" + GetExposureStatus());
        return "";
    }

    string time_filter = CheckTimeFilter();
    if(time_filter != "")
    {
        LogEntry("BLOCAGE: " + time_filter + " - Heure=" + TimeToString(GetParisTime(), TIME_MINUTES));
        return "";
    }

    string news_filter = CheckNewsFilter();
    if(news_filter != "")
    {
        LogEntry("BLOCAGE: " + news_filter + " - Fenêtre news active");
        return "";
    }

    // Tous les filtres passés !
    string direction_str = final_direction > 0 ? "LONG" : "SHORT";
    LogEntry("ENTRÉE VALIDÉE: " + direction_str + " avec " + IntegerToString(active_signals_count) + " signaux");
    return direction_str + ":" + active_signals;
}

string GetExposureStatus()
{
    int count = 0;
    string symbols = "";

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;
        count++;
        symbols += position.Symbol() + " ";
    }

    return IntegerToString(count) + " positions [" + symbols + "]";
}

//+------------------------------------------------------------------+
//| GESTION DES POSITIONS                                           |
//+------------------------------------------------------------------+
void OpenPosition(string entry_signal)
{
    string parts[];
    StringSplit(entry_signal, ':', parts);
    string direction = parts[0];
    string signals = parts[1];

    bool is_long = (direction == "LONG");
    double current_price = is_long ? SymbolInfoDouble(current_symbol, SYMBOL_ASK) :
                                   SymbolInfoDouble(current_symbol, SYMBOL_BID);

    // Calcul SL et TP
    double sl_price, tp_price;
    if(is_long)
    {
        sl_price = current_price * (1 - stop_loss_pct / 100.0);
        tp_price = current_price * (1 + take_profit_pct / 100.0);
    }
    else
    {
        sl_price = current_price * (1 + stop_loss_pct / 100.0);
        tp_price = current_price * (1 - take_profit_pct / 100.0);
    }

    double lot_size = CalculateLotSize();
    bool success = false;

    if(is_long)
        success = trade.Buy(lot_size, current_symbol, current_price, sl_price, tp_price, "HERMES_V2 " + direction);
    else
        success = trade.Sell(lot_size, current_symbol, current_price, sl_price, tp_price, "HERMES_V2 " + direction);

    if(success)
    {
        be_applied = false;

        string entry_log = StringFormat(
            "POSITION OUVERTE: %s | Prix=%.5f | SL=%.5f (%.2f%%) | TP=%.5f (%.2f%%) | Lot=%.2f | Magic=%d | Signaux=%s",
            direction, current_price, sl_price, stop_loss_pct, tp_price, take_profit_pct, lot_size, HERMES_MAGIC, signals
        );

        Print(entry_log);
        LogEntry(entry_log);
        LogEntry("IMPORTANT: Position ouverte avec Magic " + IntegerToString(HERMES_MAGIC) + " - Total positions maintenant: " + IntegerToString(PositionsTotal()));
    }
    else
    {
        string error_msg = "ERREUR POSITION: " + IntegerToString(trade.ResultRetcode()) + " - " + trade.ResultRetcodeDescription();
        Print(error_msg);
        LogEntry(error_msg);
    }
}

void ManageBreakEven()
{
    if(be_applied) return;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;
        if(position.Symbol() != current_symbol) continue;

        double open_price = position.PriceOpen();
        double current_price = (position.PositionType() == POSITION_TYPE_BUY) ?
                              SymbolInfoDouble(current_symbol, SYMBOL_BID) :
                              SymbolInfoDouble(current_symbol, SYMBOL_ASK);

        double profit_pct = 0;
        if(position.PositionType() == POSITION_TYPE_BUY)
            profit_pct = (current_price - open_price) / open_price * 100.0;
        else
            profit_pct = (open_price - current_price) / open_price * 100.0;

        // Déclenchement Break-Even à +1R
        if(profit_pct >= be_trigger_pct)
        {
            if(trade.PositionModify(position.Ticket(), open_price, position.TakeProfit()))
            {
                be_applied = true;
                string be_msg = "BREAK-EVEN APPLIQUÉ: " + current_symbol + " à " + DoubleToString(open_price, 5);
                Print(be_msg);
                LogEntry(be_msg);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS PRINCIPALES EA                                        |
//+------------------------------------------------------------------+
int OnInit()
{
    current_symbol = Symbol();
    if(!IsValidCrypto(current_symbol))
    {
        Print("HERMES V2 ERROR: Crypto non supportée: ", current_symbol);
        Print("HERMES V2: Cryptos supportées: BTCUSD, ETHUSD, SOLUSD");
        return INIT_FAILED;
    }

    trade.SetExpertMagicNumber(HERMES_MAGIC);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    // Initialisation 3 CROSS H1 (avec paramètres input)
    h1_ema21_handle = iMA(current_symbol, PERIOD_H1, ema21_h1_period, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema55_handle = iMA(current_symbol, PERIOD_H1, ema55_h1_period, 0, MODE_EMA, PRICE_CLOSE);
    h1_smma50_handle = iMA(current_symbol, PERIOD_H1, smma50_h1_period, 0, MODE_SMMA, PRICE_CLOSE);
    h1_smma200_handle = iMA(current_symbol, PERIOD_H1, smma200_h1_period, 0, MODE_SMMA, PRICE_CLOSE);
    h1_smma14_handle = iMA(current_symbol, PERIOD_H1, smma14_h1_period, 0, MODE_SMMA, PRICE_CLOSE);
    h1_smma28_handle = iMA(current_symbol, PERIOD_H1, smma28_h1_period, 0, MODE_SMMA, PRICE_CLOSE);

    // Initialisation indicateurs H4 (avec paramètres input)
    h4_smma200_handle = iMA(current_symbol, PERIOD_H4, smma_filter_period, 0, MODE_SMMA, PRICE_CLOSE);
    h4_rsi_handle = iRSI(current_symbol, PERIOD_H4, rsi_h4_period, PRICE_CLOSE);

    if(h1_ema21_handle == INVALID_HANDLE || h1_ema55_handle == INVALID_HANDLE ||
       h1_smma50_handle == INVALID_HANDLE || h1_smma200_handle == INVALID_HANDLE ||
       h1_smma14_handle == INVALID_HANDLE || h1_smma28_handle == INVALID_HANDLE ||
       h4_smma200_handle == INVALID_HANDLE || h4_rsi_handle == INVALID_HANDLE)
    {
        Print("HERMES V2 ERROR: Échec initialisation indicateurs");
        return INIT_FAILED;
    }

    // Configuration des buffers de calcul
    // Configuration des buffers 3 CROSS H1
    ArraySetAsSeries(h1_ema21, true);
    ArraySetAsSeries(h1_ema55, true);
    ArraySetAsSeries(h1_smma50, true);
    ArraySetAsSeries(h1_smma200, true);
    ArraySetAsSeries(h1_smma14, true);
    ArraySetAsSeries(h1_smma28, true);
    ArraySetAsSeries(h4_smma200, true);
    ArraySetAsSeries(h4_rsi, true);


    string start_msg = StringFormat(
        "HERMES V2 3-CROSS: %s | 4 SIGNAUX (3 cross H1 + volatilité daily) | Min=%d/4 | VolatilitéDaily>=%.2f%% | Cross séparation>=%.2f%% | Consensus>=%.1f%%",
        current_symbol, min_signals_required, daily_volatility_threshold, min_cross_separation, min_direction_consensus
    );

    Print(start_msg);
    LogEntry(start_msg);

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    // Libération indicateurs H1
    IndicatorRelease(h1_ema21_handle);
    IndicatorRelease(h1_ema55_handle);
    IndicatorRelease(h1_smma50_handle);
    IndicatorRelease(h1_smma200_handle);

    // Libération indicateurs H4
    IndicatorRelease(h4_smma200_handle);
    IndicatorRelease(h4_rsi_handle);

    // Libération nouveaux indicateurs H1
    IndicatorRelease(h1_smma14_handle);
    IndicatorRelease(h1_smma28_handle);

    if(log_handle != INVALID_HANDLE)
    {
        LogEntry("HERMES V2 ARRÊTÉ - Raison: " + IntegerToString(reason));
        FileClose(log_handle);
    }

    Print("HERMES V2 arrêté");
}


void OnTick()
{
    static datetime last_h1_time = 0;

    datetime current_h1_time = iTime(current_symbol, PERIOD_H1, 0);
    bool new_h1_candle = (current_h1_time != last_h1_time);

    // Gestion Break-Even à chaque tick
    ManageBreakEven();

    // Évaluation entrées UNIQUEMENT sur nouvelles bougies H1
    if(new_h1_candle)
    {
        last_h1_time = current_h1_time;
        LogEntry("NOUVELLE BOUGIE H1 - Évaluation signaux...");

        if(!UpdateIndicatorData())
        {
            LogEntry("ERREUR: Échec mise à jour indicateurs");
            return;
        }

        string entry_signal = EvaluateEntry();
        if(entry_signal != "")
        {
            OpenPosition(entry_signal);
        }
    }
}
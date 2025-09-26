//+------------------------------------------------------------------+
//|                                                    HERMES_V2.MQ5 |
//|                              Algo Momentum Following BTC/ETH/SOL |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

// Indicateurs H1
#property indicator_label1  "EMA21_H1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "EMA55_H1"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "SMMA50_H1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGreen
#property indicator_width3  2

#property indicator_label4  "SMMA200_H1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDarkGreen
#property indicator_width4  3

// Indicateurs M15
#property indicator_label5  "EMA21_M15"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCyan
#property indicator_width5  1

#property indicator_label6  "EMA55_M15"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_width6  1

#property indicator_label7  "SMMA14_M15"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrYellow
#property indicator_width7  1

#property indicator_label8  "SMMA28_M15"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrOrange
#property indicator_width8  1

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

// Seuils de signaux
input double m15_momentum_threshold = 0.50;     // Momentum M15 minimum (%)

// Système de validation flexible
input int min_signals_required = 4;             // Minimum signaux requis (4/5)
input int signal_validity_hours = 3;            // Validité signal en heures

// Filtres RSI
input int rsi_overbought_h4 = 80;               // RSI H4 sur-acheté
input int rsi_oversold_h4 = 20;                 // RSI H4 sur-vendu

// Filtre SMMA pour optimisation
input int smma_filter_period = 200;             // Période SMMA filtre (plus souple que 50)

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

// Indicateurs handles
int h1_ema21_handle, h1_ema55_handle;
int h1_smma50_handle, h1_smma200_handle;
int h4_smma200_handle, h4_rsi_handle;
// Nouveaux indicateurs M15
int m15_ema21_handle, m15_ema55_handle;
int m15_smma14_handle, m15_smma28_handle;

// Buffers indicateurs (calcul)
double h1_ema21[], h1_ema55[];
double h1_smma50[], h1_smma200[];
double h4_smma200[], h4_rsi[];
// Nouveaux buffers M15 (calcul)
double m15_ema21[], m15_ema55[];
double m15_smma14[], m15_smma28[];

// Buffers d'affichage pour graphique
double display_ema21_h1[];
double display_ema55_h1[];
double display_smma50_h1[];
double display_smma200_h1[];
double display_ema21_m15[];
double display_ema55_m15[];
double display_smma14_m15[];
double display_smma28_m15[];

// Variables de gestion
bool be_applied = false;
string current_symbol = "";
int log_handle = INVALID_HANDLE;

// Système de suivi des signaux (5 signaux)
datetime last_ema_cross_time = 0;
datetime last_smma_cross_time = 0;
datetime last_momentum_time = 0;
int last_ema_direction = 0;
int last_smma_direction = 0;
int last_momentum_direction = 0;
// Nouveaux signaux M15
datetime last_ema_m15_cross_time = 0;
datetime last_smma_m15_cross_time = 0;
int last_ema_m15_direction = 0;
int last_smma_m15_direction = 0;

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

    // Nouveaux indicateurs M15
    if(CopyBuffer(m15_ema21_handle, 0, 0, 3, m15_ema21) <= 0) return false;
    if(CopyBuffer(m15_ema55_handle, 0, 0, 3, m15_ema55) <= 0) return false;
    if(CopyBuffer(m15_smma14_handle, 0, 0, 3, m15_smma14) <= 0) return false;
    if(CopyBuffer(m15_smma28_handle, 0, 0, 3, m15_smma28) <= 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| SIGNAUX D'ENTRÉE AVEC SUIVI FLEXIBLE (5 SIGNAUX)              |
//+------------------------------------------------------------------+

// 1. Cross EMA21/55 H1 (EMA21 guide la dynamique)
void CheckEMACross()
{
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
        last_ema_direction = current_cross;
        last_ema_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: EMA21/55 CROSS " + direction + " - EMA21 guide la dynamique");
    }
}

// 2. Cross SMMA50/200 H1 (SMMA50 guide le trend - suit mieux le prix)
void CheckSMMACross()
{
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
        last_smma_direction = current_cross;
        last_smma_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: SMMA50/200 CROSS " + direction + " - SMMA50 suit le prix");
    }
}

// 3. Momentum M15
void CheckMomentumM15()
{
    double open = iOpen(current_symbol, PERIOD_M15, 1);
    double close = iClose(current_symbol, PERIOD_M15, 1);
    double momentum_pct = (close - open) / open * 100.0;

    if(MathAbs(momentum_pct) >= m15_momentum_threshold)
    {
        last_momentum_direction = momentum_pct > 0 ? 1 : -1;
        last_momentum_time = GetParisTime();
        string direction = last_momentum_direction > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: MOMENTUM_M15 " + direction + " - " + DoubleToString(momentum_pct, 2) + "%");
    }
}

// 4. Cross EMA21/55 M15 (EMA21 guide la dynamique)
void CheckEMACrossM15()
{
    // Détection du cross M15
    int current_cross = 0;

    // Long: EMA21 croise au-dessus d'EMA55
    if(m15_ema21[0] > m15_ema55[0] && m15_ema21[1] <= m15_ema55[1])
        current_cross = 1;

    // Short: EMA21 croise en-dessous d'EMA55
    else if(m15_ema21[0] < m15_ema55[0] && m15_ema21[1] >= m15_ema55[1])
        current_cross = -1;

    if(current_cross != 0)
    {
        last_ema_m15_direction = current_cross;
        last_ema_m15_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: EMA21/55_M15 CROSS " + direction + " - EMA21 guide M15");
    }
}

// 5. Cross SMMA14/28 M15 (SMMA14 guide - plus petite moyenne)
void CheckSMMACrossM15()
{
    // Détection du cross M15
    int current_cross = 0;

    // Long: SMMA14 croise au-dessus de SMMA28
    if(m15_smma14[0] > m15_smma28[0] && m15_smma14[1] <= m15_smma28[1])
        current_cross = 1;

    // Short: SMMA14 croise en-dessous de SMMA28
    else if(m15_smma14[0] < m15_smma28[0] && m15_smma14[1] >= m15_smma28[1])
        current_cross = -1;

    if(current_cross != 0)
    {
        last_smma_m15_direction = current_cross;
        last_smma_m15_cross_time = GetParisTime();
        string direction = current_cross > 0 ? "LONG" : "SHORT";
        LogEntry("SIGNAL: SMMA14/28_M15 CROSS " + direction + " - SMMA14 guide M15");
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

bool IsEMADirectionValid()
{
    if(!IsSignalStillValid(last_ema_cross_time)) return false;

    // Vérification que EMA21 suit toujours la direction
    if(last_ema_direction > 0)
        return h1_ema21[0] > h1_ema55[0];  // EMA21 toujours au-dessus
    else if(last_ema_direction < 0)
        return h1_ema21[0] < h1_ema55[0];  // EMA21 toujours en-dessous

    return false;
}

bool IsSMMADirectionValid()
{
    if(!IsSignalStillValid(last_smma_cross_time)) return false;

    // Vérification que SMMA50 suit toujours la direction
    if(last_smma_direction > 0)
        return h1_smma50[0] > h1_smma200[0];  // SMMA50 toujours au-dessus
    else if(last_smma_direction < 0)
        return h1_smma50[0] < h1_smma200[0];  // SMMA50 toujours en-dessous

    return false;
}


bool IsMomentumValid()
{
    return IsSignalStillValid(last_momentum_time) && last_momentum_direction != 0;
}

bool IsEMAM15DirectionValid()
{
    if(!IsSignalStillValid(last_ema_m15_cross_time)) return false;

    // Vérification que EMA21 M15 suit toujours la direction
    if(last_ema_m15_direction > 0)
        return m15_ema21[0] > m15_ema55[0];  // EMA21 toujours au-dessus
    else if(last_ema_m15_direction < 0)
        return m15_ema21[0] < m15_ema55[0];  // EMA21 toujours en-dessous

    return false;
}

bool IsSMMAM15DirectionValid()
{
    if(!IsSignalStillValid(last_smma_m15_cross_time)) return false;

    // Vérification que SMMA14 M15 suit toujours la direction
    if(last_smma_m15_direction > 0)
        return m15_smma14[0] > m15_smma28[0];  // SMMA14 toujours au-dessus
    else if(last_smma_m15_direction < 0)
        return m15_smma14[0] < m15_smma28[0];  // SMMA14 toujours en-dessous

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
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;

        string pos_symbol = position.Symbol();

        // Même crypto
        if(block_same_pair_on_off && pos_symbol == current_symbol)
            return "FILTER_EXPO_SAME";

        // Autre crypto
        if(block_other_crypto_on_off && pos_symbol != current_symbol)
        {
            for(int j = 0; j < ArraySize(supported_cryptos); j++)
            {
                if(StringFind(pos_symbol, supported_cryptos[j]) >= 0)
                    return "FILTER_EXPO_OTHER";
            }
        }
    }

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
    // Mise à jour des signaux (détection nouveaux cross/mouvements)
    CheckEMACross();
    CheckSMMACross();
    CheckMomentumM15();
    CheckEMACrossM15();      // Signal M15
    CheckSMMACrossM15();     // Signal M15

    // Vérification des signaux valides actuellement (5 signaux)
    bool ema_h1_valid = IsEMADirectionValid();
    bool smma_h1_valid = IsSMMADirectionValid();
    bool momentum_valid = IsMomentumValid();
    bool ema_m15_valid = IsEMAM15DirectionValid();
    bool smma_m15_valid = IsSMMAM15DirectionValid();

    // Comptage des signaux actifs (5 signaux total)
    int active_signals_count = 0;
    int direction_sum = 0;
    string active_signals = "";

    if(ema_h1_valid)
    {
        active_signals_count++;
        direction_sum += last_ema_direction;
        active_signals += last_ema_direction > 0 ? "EMA21_H1_LONG " : "EMA21_H1_SHORT ";
    }

    if(smma_h1_valid)
    {
        active_signals_count++;
        direction_sum += last_smma_direction;
        active_signals += last_smma_direction > 0 ? "SMMA50_H1_LONG " : "SMMA50_H1_SHORT ";
    }

    if(momentum_valid)
    {
        active_signals_count++;
        direction_sum += last_momentum_direction;
        active_signals += last_momentum_direction > 0 ? "MOM_M15_LONG " : "MOM_M15_SHORT ";
    }

    if(ema_m15_valid)
    {
        active_signals_count++;
        direction_sum += last_ema_m15_direction;
        active_signals += last_ema_m15_direction > 0 ? "EMA21_M15_LONG " : "EMA21_M15_SHORT ";
    }

    if(smma_m15_valid)
    {
        active_signals_count++;
        direction_sum += last_smma_m15_direction;
        active_signals += last_smma_m15_direction > 0 ? "SMMA14_M15_LONG " : "SMMA14_M15_SHORT ";
    }

    // Vérification minimum de signaux requis (4/5)
    if(active_signals_count < min_signals_required)
    {
        if(active_signals_count > 0)
        {
            LogEntry("SIGNAUX INSUFFISANTS: " + IntegerToString(active_signals_count) + "/5 (min " + IntegerToString(min_signals_required) + ") - Signaux: " + active_signals);
        }
        return "";
    }

    // Détermination direction finale
    int final_direction = direction_sum > 0 ? 1 : (direction_sum < 0 ? -1 : 0);
    if(final_direction == 0)
    {
        LogEntry("DIRECTION INDÉTERMINÉE: Signaux contradictoires - " + active_signals);
        return "";
    }

    LogEntry("SIGNAUX VALIDÉS: " + IntegerToString(active_signals_count) + "/5 - Direction: " + (final_direction > 0 ? "LONG" : "SHORT") + " - " + active_signals);

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
            "POSITION OUVERTE: %s | Prix=%.5f | SL=%.5f (%.2f%%) | TP=%.5f (%.2f%%) | Lot=%.2f | Signaux=%s",
            direction, current_price, sl_price, stop_loss_pct, tp_price, take_profit_pct, lot_size, signals
        );

        Print(entry_log);
        LogEntry(entry_log);
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

    // Initialisation indicateurs H1
    h1_ema21_handle = iMA(current_symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema55_handle = iMA(current_symbol, PERIOD_H1, 55, 0, MODE_EMA, PRICE_CLOSE);
    h1_smma50_handle = iMA(current_symbol, PERIOD_H1, 50, 0, MODE_SMMA, PRICE_CLOSE);
    h1_smma200_handle = iMA(current_symbol, PERIOD_H1, 200, 0, MODE_SMMA, PRICE_CLOSE);

    // Initialisation indicateurs H4
    h4_smma200_handle = iMA(current_symbol, PERIOD_H4, smma_filter_period, 0, MODE_SMMA, PRICE_CLOSE);
    h4_rsi_handle = iRSI(current_symbol, PERIOD_H4, 14, PRICE_CLOSE);

    // Initialisation nouveaux indicateurs M15
    m15_ema21_handle = iMA(current_symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
    m15_ema55_handle = iMA(current_symbol, PERIOD_M15, 55, 0, MODE_EMA, PRICE_CLOSE);
    m15_smma14_handle = iMA(current_symbol, PERIOD_M15, 14, 0, MODE_SMMA, PRICE_CLOSE);
    m15_smma28_handle = iMA(current_symbol, PERIOD_M15, 28, 0, MODE_SMMA, PRICE_CLOSE);

    if(h1_ema21_handle == INVALID_HANDLE || h1_ema55_handle == INVALID_HANDLE ||
       h1_smma50_handle == INVALID_HANDLE || h1_smma200_handle == INVALID_HANDLE ||
       h4_smma200_handle == INVALID_HANDLE || h4_rsi_handle == INVALID_HANDLE ||
       m15_ema21_handle == INVALID_HANDLE || m15_ema55_handle == INVALID_HANDLE ||
       m15_smma14_handle == INVALID_HANDLE || m15_smma28_handle == INVALID_HANDLE)
    {
        Print("HERMES V2 ERROR: Échec initialisation indicateurs");
        return INIT_FAILED;
    }

    // Configuration des buffers de calcul
    ArraySetAsSeries(h1_ema21, true);
    ArraySetAsSeries(h1_ema55, true);
    ArraySetAsSeries(h1_smma50, true);
    ArraySetAsSeries(h1_smma200, true);
    ArraySetAsSeries(h4_smma200, true);
    ArraySetAsSeries(h4_rsi, true);
    ArraySetAsSeries(m15_ema21, true);
    ArraySetAsSeries(m15_ema55, true);
    ArraySetAsSeries(m15_smma14, true);
    ArraySetAsSeries(m15_smma28, true);

    // Configuration des buffers d'affichage
    SetIndexBuffer(0, display_ema21_h1, INDICATOR_DATA);
    SetIndexBuffer(1, display_ema55_h1, INDICATOR_DATA);
    SetIndexBuffer(2, display_smma50_h1, INDICATOR_DATA);
    SetIndexBuffer(3, display_smma200_h1, INDICATOR_DATA);
    SetIndexBuffer(4, display_ema21_m15, INDICATOR_DATA);
    SetIndexBuffer(5, display_ema55_m15, INDICATOR_DATA);
    SetIndexBuffer(6, display_smma14_m15, INDICATOR_DATA);
    SetIndexBuffer(7, display_smma28_m15, INDICATOR_DATA);

    // Configuration des séries
    ArraySetAsSeries(display_ema21_h1, true);
    ArraySetAsSeries(display_ema55_h1, true);
    ArraySetAsSeries(display_smma50_h1, true);
    ArraySetAsSeries(display_smma200_h1, true);
    ArraySetAsSeries(display_ema21_m15, true);
    ArraySetAsSeries(display_ema55_m15, true);
    ArraySetAsSeries(display_smma14_m15, true);
    ArraySetAsSeries(display_smma28_m15, true);

    string start_msg = StringFormat(
        "HERMES V2 DÉMARRÉ: %s | 5 SIGNAUX | Min=%d/5 | R:R=1:5 | SL=%.2f%% | TP=%.2f%% | BE=%.2f%% | Trading=%d:00-%d:00 | SMMA_Filter=%d",
        current_symbol, min_signals_required, stop_loss_pct, take_profit_pct, be_trigger_pct, trading_start_hour, trading_end_hour, smma_filter_period
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

    // Libération nouveaux indicateurs M15
    IndicatorRelease(m15_ema21_handle);
    IndicatorRelease(m15_ema55_handle);
    IndicatorRelease(m15_smma14_handle);
    IndicatorRelease(m15_smma28_handle);

    if(log_handle != INVALID_HANDLE)
    {
        LogEntry("HERMES V2 ARRÊTÉ - Raison: " + IntegerToString(reason));
        FileClose(log_handle);
    }

    Print("HERMES V2 arrêté");
}

//+------------------------------------------------------------------+
//| Fonction OnCalculate pour affichage des indicateurs            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total < 200) return 0; // Pas assez de données

    int limit = rates_total - prev_calculated;
    if(limit > rates_total - 200) limit = rates_total - 200;

    // Mise à jour des buffers d'affichage avec les données des indicateurs
    for(int i = limit - 1; i >= 0; i--)
    {
        // Copie des données H1 vers buffers d'affichage
        if(CopyBuffer(h1_ema21_handle, 0, time[i], 1, h1_ema21) > 0)
            display_ema21_h1[i] = h1_ema21[0];

        if(CopyBuffer(h1_ema55_handle, 0, time[i], 1, h1_ema55) > 0)
            display_ema55_h1[i] = h1_ema55[0];

        if(CopyBuffer(h1_smma50_handle, 0, time[i], 1, h1_smma50) > 0)
            display_smma50_h1[i] = h1_smma50[0];

        if(CopyBuffer(h1_smma200_handle, 0, time[i], 1, h1_smma200) > 0)
            display_smma200_h1[i] = h1_smma200[0];

        // Copie des données M15 vers buffers d'affichage
        if(CopyBuffer(m15_ema21_handle, 0, time[i], 1, m15_ema21) > 0)
            display_ema21_m15[i] = m15_ema21[0];

        if(CopyBuffer(m15_ema55_handle, 0, time[i], 1, m15_ema55) > 0)
            display_ema55_m15[i] = m15_ema55[0];

        if(CopyBuffer(m15_smma14_handle, 0, time[i], 1, m15_smma14) > 0)
            display_smma14_m15[i] = m15_smma14[0];

        if(CopyBuffer(m15_smma28_handle, 0, time[i], 1, m15_smma28) > 0)
            display_smma28_m15[i] = m15_smma28[0];
    }

    return rates_total;
}

void OnTick()
{
    static datetime last_m15_time = 0;
    static datetime last_h1_time = 0;

    datetime current_m15_time = iTime(current_symbol, PERIOD_M15, 0);
    datetime current_h1_time = iTime(current_symbol, PERIOD_H1, 0);

    bool new_m15_candle = (current_m15_time != last_m15_time);
    bool new_h1_candle = (current_h1_time != last_h1_time);

    // Gestion Break-Even à chaque tick
    ManageBreakEven();

    // Évaluation entrées sur nouvelles bougies
    if(new_m15_candle || new_h1_candle)
    {
        last_m15_time = current_m15_time;
        last_h1_time = current_h1_time;

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
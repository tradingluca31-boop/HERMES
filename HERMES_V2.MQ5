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

// Seuils de signaux
input double movement_threshold_h1 = 0.50;      // Mouvement H1 minimum (%)
input double m15_momentum_threshold = 0.50;     // Momentum M15 minimum (%)

// Filtres RSI
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

// Indicateurs handles
int h1_ema21_handle, h1_ema55_handle;
int h1_smma50_handle, h1_smma200_handle;
int h4_smma200_handle, h4_rsi_handle;

// Buffers indicateurs
double h1_ema21[], h1_ema55[];
double h1_smma50[], h1_smma200[];
double h4_smma200[], h4_rsi[];

// Variables de gestion
bool be_applied = false;
string current_symbol = "";
int log_handle = INVALID_HANDLE;

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
    if(CopyBuffer(h1_ema21_handle, 0, 0, 3, h1_ema21) <= 0) return false;
    if(CopyBuffer(h1_ema55_handle, 0, 0, 3, h1_ema55) <= 0) return false;
    if(CopyBuffer(h1_smma50_handle, 0, 0, 3, h1_smma50) <= 0) return false;
    if(CopyBuffer(h1_smma200_handle, 0, 0, 3, h1_smma200) <= 0) return false;
    if(CopyBuffer(h4_smma200_handle, 0, 0, 3, h4_smma200) <= 0) return false;
    if(CopyBuffer(h4_rsi_handle, 0, 0, 3, h4_rsi) <= 0) return false;
    return true;
}

//+------------------------------------------------------------------+
//| SIGNAUX D'ENTRÉE                                                |
//+------------------------------------------------------------------+

// 1. Mouvement H1 minimum
bool CheckMovementH1()
{
    double open = iOpen(current_symbol, PERIOD_H1, 1);
    double close = iClose(current_symbol, PERIOD_H1, 1);
    double movement_pct = MathAbs(close - open) / open * 100.0;

    return movement_pct >= movement_threshold_h1;
}

// 2. Cross EMA21/55 H1
int CheckEMACross()
{
    // Long: EMA21 croise au-dessus d'EMA55
    if(h1_ema21[0] > h1_ema55[0] && h1_ema21[1] <= h1_ema55[1])
        return 1;

    // Short: EMA21 croise en-dessous d'EMA55
    if(h1_ema21[0] < h1_ema55[0] && h1_ema21[1] >= h1_ema55[1])
        return -1;

    return 0;
}

// 3. Cross SMMA50/200 H1
int CheckSMMACross()
{
    // Long: SMMA50 croise au-dessus de SMMA200
    if(h1_smma50[0] > h1_smma200[0] && h1_smma50[1] <= h1_smma200[1])
        return 1;

    // Short: SMMA50 croise en-dessous de SMMA200
    if(h1_smma50[0] < h1_smma200[0] && h1_smma50[1] >= h1_smma200[1])
        return -1;

    return 0;
}

// 4. Momentum M15
int CheckMomentumM15()
{
    double open = iOpen(current_symbol, PERIOD_M15, 1);
    double close = iClose(current_symbol, PERIOD_M15, 1);
    double momentum_pct = (close - open) / open * 100.0;

    if(MathAbs(momentum_pct) >= m15_momentum_threshold)
    {
        return momentum_pct > 0 ? 1 : -1;
    }

    return 0;
}

//+------------------------------------------------------------------+
//| FILTRES D'EXCLUSION                                             |
//+------------------------------------------------------------------+

// 1. Tendance H4 (SMMA200)
bool CheckTrendH4Filter(int direction)
{
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    if(direction > 0) // Long uniquement si cours > SMMA200 H4
        return current_price > h4_smma200[0];
    else if(direction < 0) // Short uniquement si cours < SMMA200 H4
        return current_price < h4_smma200[0];

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
//| ÉVALUATION COMPLÈTE                                             |
//+------------------------------------------------------------------+
string EvaluateEntry()
{
    // Vérification de tous les signaux
    if(!CheckMovementH1())
        return "";

    int ema_signal = CheckEMACross();
    int smma_signal = CheckSMMACross();
    int momentum_signal = CheckMomentumM15();

    // Détermine la direction principale
    int direction = 0;
    string active_signals = "";

    if(ema_signal != 0)
    {
        direction += ema_signal;
        active_signals += ema_signal > 0 ? "EMA_LONG " : "EMA_SHORT ";
    }

    if(smma_signal != 0)
    {
        direction += smma_signal;
        active_signals += smma_signal > 0 ? "SMMA_LONG " : "SMMA_SHORT ";
    }

    if(momentum_signal != 0)
    {
        direction += momentum_signal;
        active_signals += momentum_signal > 0 ? "MOM_LONG " : "MOM_SHORT ";
    }

    // Pas assez de signaux
    if(active_signals == "") return "";

    // Normalise la direction
    int final_direction = direction > 0 ? 1 : (direction < 0 ? -1 : 0);
    if(final_direction == 0) return "";

    // Vérification de tous les filtres
    if(!CheckTrendH4Filter(final_direction))
    {
        LogEntry("BLOCAGE: FILTER_TREND_H4 - Prix=" + DoubleToString(SymbolInfoDouble(current_symbol, SYMBOL_BID), 5) +
                " vs SMMA200_H4=" + DoubleToString(h4_smma200[0], 5));
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

    // Initialisation indicateurs
    h1_ema21_handle = iMA(current_symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema55_handle = iMA(current_symbol, PERIOD_H1, 55, 0, MODE_EMA, PRICE_CLOSE);
    h1_smma50_handle = iMA(current_symbol, PERIOD_H1, 50, 0, MODE_SMMA, PRICE_CLOSE);
    h1_smma200_handle = iMA(current_symbol, PERIOD_H1, 200, 0, MODE_SMMA, PRICE_CLOSE);
    h4_smma200_handle = iMA(current_symbol, PERIOD_H4, 200, 0, MODE_SMMA, PRICE_CLOSE);
    h4_rsi_handle = iRSI(current_symbol, PERIOD_H4, 14, PRICE_CLOSE);

    if(h1_ema21_handle == INVALID_HANDLE || h1_ema55_handle == INVALID_HANDLE ||
       h1_smma50_handle == INVALID_HANDLE || h1_smma200_handle == INVALID_HANDLE ||
       h4_smma200_handle == INVALID_HANDLE || h4_rsi_handle == INVALID_HANDLE)
    {
        Print("HERMES V2 ERROR: Échec initialisation indicateurs");
        return INIT_FAILED;
    }

    ArraySetAsSeries(h1_ema21, true);
    ArraySetAsSeries(h1_ema55, true);
    ArraySetAsSeries(h1_smma50, true);
    ArraySetAsSeries(h1_smma200, true);
    ArraySetAsSeries(h4_smma200, true);
    ArraySetAsSeries(h4_rsi, true);

    string start_msg = StringFormat(
        "HERMES V2 DÉMARRÉ: %s | R:R=1:5 | SL=%.2f%% | TP=%.2f%% | BE=%.2f%% | Trading=%d:00-%d:00",
        current_symbol, stop_loss_pct, take_profit_pct, be_trigger_pct, trading_start_hour, trading_end_hour
    );

    Print(start_msg);
    LogEntry(start_msg);

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    IndicatorRelease(h1_ema21_handle);
    IndicatorRelease(h1_ema55_handle);
    IndicatorRelease(h1_smma50_handle);
    IndicatorRelease(h1_smma200_handle);
    IndicatorRelease(h4_smma200_handle);
    IndicatorRelease(h4_rsi_handle);

    if(log_handle != INVALID_HANDLE)
    {
        LogEntry("HERMES V2 ARRÊTÉ - Raison: " + IntegerToString(reason));
        FileClose(log_handle);
    }

    Print("HERMES V2 arrêté");
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
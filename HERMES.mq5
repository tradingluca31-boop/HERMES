//+------------------------------------------------------------------+
//|                                                       HERMES.MQ5 |
//|                                          Algo Momentum Following |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Paramètres                                                       |
//+------------------------------------------------------------------+
#define HERMES_MAGIC 123456789

input double stop_loss_pct = 0.70;
input double take_profit_pct = 3.50;
input double be_trigger_pct = 0.70;
input int rsi_oversold_h4 = 30;
input int rsi_overbought_h4 = 70;
input bool news_filter_on_off = true;
input bool block_same_pair_on_off = true;
input bool block_other_crypto_on_off = true;
input double risk_per_trade = 1.0;
input double min_lot_size = 0.01;
input double max_lot_size = 10.0;
input int start_hour = 8;
input int end_hour = 22;

//+------------------------------------------------------------------+
//| Structures                                                       |
//+------------------------------------------------------------------+
struct SignalResult
{
    int signal_strength;
    int direction;
    string active_signals;
};

struct FilterResult
{
    bool all_passed;
    string blocked_by;
    string context_data;
};

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
CAccountInfo account;

// Indicateurs
int h1_ema21_handle, h1_ema55_handle;
int h1_smma50_handle, h1_smma200_handle;
int h4_smma200_handle, h4_rsi_handle;

// Buffers
double h1_ema21[], h1_ema55[];
double h1_smma50[], h1_smma200[];
double h4_smma200[], h4_rsi[];

// Variables de gestion
bool be_applied = false;
string current_symbol = "";

string supported_symbols[] = {"BTCUSD", "ETHUSD", "SOLUSD"};

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                           |
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

bool CheckTimeFilter()
{
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    int current_hour = time_struct.hour;
    return (current_hour >= start_hour && current_hour <= end_hour);
}

//+------------------------------------------------------------------+
//| Signaux                                                          |
//+------------------------------------------------------------------+
bool CheckMovementH1Signal()
{
    bool ema21_rising = h1_ema21[0] > h1_ema21[1];
    bool ema55_rising = h1_ema55[0] > h1_ema55[1];
    return (ema21_rising && ema55_rising) || (!ema21_rising && !ema55_rising);
}

int CheckEMACrossSignal()
{
    bool cross_up = (h1_ema21[0] > h1_ema55[0] && h1_ema21[1] <= h1_ema55[1]);
    bool cross_down = (h1_ema21[0] < h1_ema55[0] && h1_ema21[1] >= h1_ema55[1]);

    if(cross_up) return 1;
    if(cross_down) return -1;
    return 0;
}

int CheckSMMACrossSignal()
{
    bool cross_up = (h1_smma50[0] > h1_smma200[0] && h1_smma50[1] <= h1_smma200[1]);
    bool cross_down = (h1_smma50[0] < h1_smma200[0] && h1_smma50[1] >= h1_smma200[1]);

    if(cross_up) return 1;
    if(cross_down) return -1;
    return 0;
}

int CheckMomentumM15Signal()
{
    double close_current = iClose(current_symbol, PERIOD_M15, 0);
    double close_previous = iClose(current_symbol, PERIOD_M15, 1);
    double close_2 = iClose(current_symbol, PERIOD_M15, 2);

    if(close_current > close_previous && close_previous > close_2)
        return 1;
    if(close_current < close_previous && close_previous < close_2)
        return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Filtres                                                          |
//+------------------------------------------------------------------+
bool CheckTrendH4Filter(int signal_direction)
{
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    if(signal_direction > 0)
        return current_price > h4_smma200[0];
    else if(signal_direction < 0)
        return current_price < h4_smma200[0];
    return true;
}

bool CheckRSIH4Filter(int signal_direction)
{
    if(signal_direction > 0)
        return h4_rsi[0] < rsi_overbought_h4;
    else if(signal_direction < 0)
        return h4_rsi[0] > rsi_oversold_h4;
    return true;
}

string CheckExposureFilter()
{
    if(!block_same_pair_on_off && !block_other_crypto_on_off)
        return "";

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;

        string pos_symbol = position.Symbol();

        if(block_same_pair_on_off && pos_symbol == current_symbol)
            return "FILTER_SAME_PAIR";

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

string CheckNewsFilter()
{
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);

    if(time_struct.hour == 14 && time_struct.min >= 30)
        return "News US";
    if(time_struct.hour == 15 && time_struct.min <= 30)
        return "News US";
    return "";
}

//+------------------------------------------------------------------+
//| Break-Even                                                       |
//+------------------------------------------------------------------+
bool ShouldApplyBreakEven()
{
    if(be_applied) return false;
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

void ApplyBreakEven()
{
    if(!position.Select(current_symbol)) return;
    double open_price = position.PriceOpen();

    if(trade.PositionModify(position.Ticket(), open_price, position.TakeProfit()))
    {
        be_applied = true;
        Print("Break-Even appliqué");
    }
}

//+------------------------------------------------------------------+
//| Evaluation                                                       |
//+------------------------------------------------------------------+
SignalResult EvaluateSignals()
{
    SignalResult result;
    result.signal_strength = 0;
    result.direction = 0;
    result.active_signals = "";

    if(CheckMovementH1Signal())
    {
        result.signal_strength++;
        result.active_signals += "MOVEMENT_H1 ";
    }

    int ema_cross = CheckEMACrossSignal();
    if(ema_cross != 0)
    {
        result.signal_strength++;
        result.direction += ema_cross;
        result.active_signals += (ema_cross > 0) ? "EMA_CROSS_LONG " : "EMA_CROSS_SHORT ";
    }

    int smma_cross = CheckSMMACrossSignal();
    if(smma_cross != 0)
    {
        result.signal_strength++;
        result.direction += smma_cross;
        result.active_signals += (smma_cross > 0) ? "SMMA_CROSS_LONG " : "SMMA_CROSS_SHORT ";
    }

    int momentum = CheckMomentumM15Signal();
    if(momentum != 0)
    {
        result.signal_strength++;
        result.direction += momentum;
        result.active_signals += (momentum > 0) ? "MOMENTUM_M15_LONG " : "MOMENTUM_M15_SHORT ";
    }

    if(result.direction > 0)
        result.direction = 1;
    else if(result.direction < 0)
        result.direction = -1;
    else
        result.direction = 0;

    return result;
}

FilterResult EvaluateFilters(int signal_direction)
{
    FilterResult result;
    result.all_passed = true;
    result.blocked_by = "";
    result.context_data = "";

    if(!CheckTrendH4Filter(signal_direction))
    {
        result.all_passed = false;
        result.blocked_by = "FILTER_TREND_H4";
        return result;
    }

    if(!CheckRSIH4Filter(signal_direction))
    {
        result.all_passed = false;
        result.blocked_by = "FILTER_RSI_H4";
        return result;
    }

    string expo_filter = CheckExposureFilter();
    if(expo_filter != "")
    {
        result.all_passed = false;
        result.blocked_by = expo_filter;
        return result;
    }

    if(news_filter_on_off)
    {
        string news_filter = CheckNewsFilter();
        if(news_filter != "")
        {
            result.all_passed = false;
            result.blocked_by = "FILTER_NEWS";
            return result;
        }
    }

    return result;
}

void OpenPosition(SignalResult signals)
{
    double current_price = (signals.direction > 0) ?
                          SymbolInfoDouble(current_symbol, SYMBOL_ASK) :
                          SymbolInfoDouble(current_symbol, SYMBOL_BID);

    double sl_price, tp_price;
    if(signals.direction > 0)
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

    if(signals.direction > 0)
        success = trade.Buy(lot_size, current_symbol, current_price, sl_price, tp_price, "HERMES Long");
    else
        success = trade.Sell(lot_size, current_symbol, current_price, sl_price, tp_price, "HERMES Short");

    if(success)
    {
        be_applied = false;
        Print("Position ouverte: ", (signals.direction > 0) ? "LONG" : "SHORT");
    }
    else
    {
        Print("Erreur ouverture position: ", trade.ResultRetcode());
    }
}

void ManageExistingPositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i)) continue;
        if(position.Magic() != HERMES_MAGIC) continue;
        if(position.Symbol() != current_symbol) continue;

        if(!be_applied && ShouldApplyBreakEven())
        {
            ApplyBreakEven();
        }
    }
}

void EvaluateSignalsAndFilters()
{
    if(!CheckTimeFilter()) return;

    SignalResult signals = EvaluateSignals();
    if(signals.signal_strength == 0) return;

    FilterResult filters = EvaluateFilters(signals.direction);
    if(!filters.all_passed) return;

    OpenPosition(signals);
}

//+------------------------------------------------------------------+
//| Expert Advisor fonctions principales                            |
//+------------------------------------------------------------------+
int OnInit()
{
    current_symbol = Symbol();
    if(!IsValidSymbol(current_symbol))
    {
        Print("Symbole non supporté: ", current_symbol);
        return INIT_FAILED;
    }

    trade.SetExpertMagicNumber(HERMES_MAGIC);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

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
        Print("Échec initialisation des indicateurs");
        return INIT_FAILED;
    }

    ArraySetAsSeries(h1_ema21, true);
    ArraySetAsSeries(h1_ema55, true);
    ArraySetAsSeries(h1_smma50, true);
    ArraySetAsSeries(h1_smma200, true);
    ArraySetAsSeries(h4_smma200, true);
    ArraySetAsSeries(h4_rsi, true);

    Print("HERMES démarré sur ", current_symbol);
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
    Print("HERMES arrêté");
}

void OnTick()
{
    static datetime last_m15_time = 0;
    static datetime last_h1_time = 0;

    datetime current_m15_time = iTime(current_symbol, PERIOD_M15, 0);
    datetime current_h1_time = iTime(current_symbol, PERIOD_H1, 0);

    bool new_m15_candle = (current_m15_time != last_m15_time);
    bool new_h1_candle = (current_h1_time != last_h1_time);

    ManageExistingPositions();

    if(new_m15_candle || new_h1_candle)
    {
        last_m15_time = current_m15_time;
        last_h1_time = current_h1_time;

        if(!UpdateIndicatorData()) return;
        EvaluateSignalsAndFilters();
    }
}
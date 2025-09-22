//+------------------------------------------------------------------+
//|                                                  HermesUtils.mqh |
//|                            Fonctions utilitaires Algo Hermes    |
//|                      https://github.com/tradingluca31-boop/HERMES |
//+------------------------------------------------------------------+
#property copyright "tradingluca31-boop"
#property link      "https://github.com/tradingluca31-boop/HERMES"

//+------------------------------------------------------------------+
//| Fonctions de validation des symboles                            |
//+------------------------------------------------------------------+
bool IsValidSymbol(string symbol)
{
    for(int i = 0; i < ArraySize(SUPPORTED_SYMBOLS); i++)
    {
        if(StringFind(symbol, SUPPORTED_SYMBOLS[i]) >= 0)
            return true;
    }
    return false;
}

string GetCryptoName(string symbol)
{
    if(StringFind(symbol, "BTC") >= 0) return "BTC";
    if(StringFind(symbol, "ETH") >= 0) return "ETH";
    if(StringFind(symbol, "SOL") >= 0) return "SOL";
    return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Fonctions de gestion du temps (Europe/Paris)                   |
//+------------------------------------------------------------------+
datetime GetParisTime()
{
    datetime gmt_time = TimeCurrent();
    int offset = GetParisGMTOffset(gmt_time);
    return gmt_time + offset * 3600;
}

int GetParisGMTOffset(datetime gmt_time)
{
    // Vérification heure d'été/hiver
    if(gmt_time >= DST_START_2025 && gmt_time < DST_END_2025)
        return PARIS_GMT_OFFSET_SUMMER;
    else
        return PARIS_GMT_OFFSET_WINTER;
}

bool IsInTradingHours()
{
    datetime paris_time = GetParisTime();
    MqlDateTime time_struct;
    TimeToStruct(paris_time, time_struct);

    int current_hour = time_struct.hour;
    return (current_hour >= TRADING_START_HOUR && current_hour < TRADING_END_HOUR);
}

//+------------------------------------------------------------------+
//| Fonctions d'évaluation des signaux                              |
//+------------------------------------------------------------------+
bool CheckMovementH1Signal()
{
    // Récupération données H1
    double open_h1 = iOpen(current_symbol, PERIOD_H1, 1);  // Bougie précédente
    double close_h1 = iClose(current_symbol, PERIOD_H1, 1);

    if(open_h1 <= 0 || close_h1 <= 0)
        return false;

    // Calcul variation absolue
    double movement_pct = MathAbs((close_h1 - open_h1) / open_h1) * 100.0;

    return (movement_pct >= movement_threshold_h1);
}

int CheckEMACrossSignal()
{
    // Vérification disponibilité des données
    if(CopyBuffer(h1_ema21_handle, 0, 0, 3, h1_ema21) != 3 ||
       CopyBuffer(h1_ema55_handle, 0, 0, 3, h1_ema55) != 3)
        return 0;

    // Détection croisement (bougie précédente vs actuelle)
    bool was_above = (h1_ema21[2] > h1_ema55[2]);  // 2 bougies avant
    bool is_above = (h1_ema21[1] > h1_ema55[1]);   // Bougie précédente

    // Nouveau croisement haussier
    if(!was_above && is_above)
        return 1;   // Signal Long

    // Nouveau croisement baissier
    if(was_above && !is_above)
        return -1;  // Signal Short

    return 0;       // Pas de nouveau croisement
}

int CheckSMMACrossSignal()
{
    // Vérification disponibilité des données
    if(CopyBuffer(h1_smma50_handle, 0, 0, 3, h1_smma50) != 3 ||
       CopyBuffer(h1_smma200_handle, 0, 0, 3, h1_smma200) != 3)
        return 0;

    // Détection croisement
    bool was_above = (h1_smma50[2] > h1_smma200[2]);
    bool is_above = (h1_smma50[1] > h1_smma200[1]);

    if(!was_above && is_above)
        return 1;   // Signal Long

    if(was_above && !is_above)
        return -1;  // Signal Short

    return 0;
}

int CheckMomentumM15Signal()
{
    // Récupération données M15
    double open_m15 = iOpen(current_symbol, PERIOD_M15, 1);
    double close_m15 = iClose(current_symbol, PERIOD_M15, 1);

    if(open_m15 <= 0 || close_m15 <= 0)
        return 0;

    // Calcul momentum
    double momentum_pct = ((close_m15 - open_m15) / open_m15) * 100.0;

    // Vérification seuil
    if(MathAbs(momentum_pct) < m15_momentum_threshold)
        return 0;

    return (momentum_pct > 0) ? 1 : -1;
}

//+------------------------------------------------------------------+
//| Fonctions d'évaluation des filtres                              |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
    return IsInTradingHours();
}

bool CheckTrendH4Filter(int signal_direction)
{
    if(CopyBuffer(h4_smma200_handle, 0, 0, 1, h4_smma200) != 1)
        return false;

    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    if(signal_direction > 0)  // Signal Long
        return (current_price > h4_smma200[0]);
    else                      // Signal Short
        return (current_price < h4_smma200[0]);
}

bool CheckRSIH4Filter(int signal_direction)
{
    if(CopyBuffer(h4_rsi_handle, 0, 0, 1, h4_rsi) != 1)
        return false;

    double rsi_value = h4_rsi[0];

    if(signal_direction > 0)  // Signal Long
        return (rsi_value < rsi_overbought_h4);
    else                      // Signal Short
        return (rsi_value > rsi_oversold_h4);
}

string CheckExposureFilter()
{
    int same_crypto_positions = 0;
    int other_crypto_positions = 0;
    string current_crypto = GetCryptoName(current_symbol);

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i))
            continue;

        if(position.Magic() != HERMES_MAGIC)
            continue;

        string pos_crypto = GetCryptoName(position.Symbol());

        if(pos_crypto == current_crypto)
            same_crypto_positions++;
        else
            other_crypto_positions++;
    }

    // Vérification filtre même crypto
    if(block_same_pair_on_off && same_crypto_positions > 0)
        return "FILTER_EXPO_SAME";

    // Vérification filtre autres cryptos
    if(block_other_crypto_on_off && other_crypto_positions > 0)
        return "FILTER_EXPO_OTHER";

    return "";  // Pas de blocage
}

string GetExposureStatus()
{
    int btc_pos = 0, eth_pos = 0, sol_pos = 0;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!position.SelectByIndex(i))
            continue;

        if(position.Magic() != HERMES_MAGIC)
            continue;

        string crypto = GetCryptoName(position.Symbol());
        if(crypto == "BTC") btc_pos++;
        else if(crypto == "ETH") eth_pos++;
        else if(crypto == "SOL") sol_pos++;
    }

    return StringFormat("Positions: BTC=%d, ETH=%d, SOL=%d", btc_pos, eth_pos, sol_pos);
}

string CheckNewsFilter()
{
    // Simplification: vérification basique des heures de news importantes
    datetime paris_time = GetParisTime();
    MqlDateTime time_struct;
    TimeToStruct(paris_time, time_struct);

    // News US généralement à 14:30 et 16:00 heure de Paris
    int current_minute = time_struct.hour * 60 + time_struct.min;

    // Heures importantes en minutes depuis minuit
    int news_times[] = {
        14*60 + 30,  // 14:30 - CPI, PPI, etc.
        16*60 + 0,   // 16:00 - FOMC, etc.
        15*60 + 30   // 15:30 - Autres news
    };

    for(int i = 0; i < ArraySize(news_times); i++)
    {
        int diff = MathAbs(current_minute - news_times[i]);
        if(diff <= news_block_minutes)
        {
            return StringFormat("News dans %d minutes", news_block_minutes - diff);
        }
    }

    return "";  // Pas de news
}

//+------------------------------------------------------------------+
//| Fonctions de gestion des positions                              |
//+------------------------------------------------------------------+
bool ShouldApplyBreakEven()
{
    if(!position.Select(current_symbol))
        return false;

    double entry_price = position.PriceOpen();
    double current_price = (position.PositionType() == POSITION_TYPE_BUY) ?
                          SymbolInfoDouble(current_symbol, SYMBOL_BID) :
                          SymbolInfoDouble(current_symbol, SYMBOL_ASK);

    double profit_pct = 0;
    if(position.PositionType() == POSITION_TYPE_BUY)
        profit_pct = ((current_price - entry_price) / entry_price) * 100.0;
    else
        profit_pct = ((entry_price - current_price) / entry_price) * 100.0;

    return (profit_pct >= be_trigger_pct);
}

void ApplyBreakEven()
{
    if(!position.Select(current_symbol))
        return;

    double entry_price = position.PriceOpen();

    if(trade.PositionModify(position.Ticket(), entry_price, position.TakeProfit()))
    {
        be_applied = true;

        string be_log = StringFormat(
            "=== BREAK-EVEN APPLIQUÉ ===\n" +
            "Symbole: %s\n" +
            "Ticket: %I64u\n" +
            "Prix d'entrée: %.5f\n" +
            "Nouveau SL: %.5f\n" +
            "Heure: %s (Europe/Paris)",
            current_symbol,
            position.Ticket(),
            entry_price,
            entry_price,
            TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES)
        );

        Print(be_log);
        LogMessage("BREAKEVEN", be_log);

        if(enable_sound_alerts)
            PlaySound(SOUND_BE);
    }
}

double CalculateLotSize()
{
    double balance = account.Balance();
    double risk_amount = balance * risk_per_trade_pct / 100.0;

    double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
    double current_price = SymbolInfoDouble(current_symbol, SYMBOL_BID);

    double sl_distance = current_price * stop_loss_pct / 100.0;
    double sl_distance_ticks = sl_distance / tick_size;

    double lot_size = risk_amount / (sl_distance_ticks * tick_value);

    // Vérification limites
    double min_lot = SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_STEP);

    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = NormalizeDouble(lot_size / lot_step, 0) * lot_step;

    return lot_size;
}

//+------------------------------------------------------------------+
//| Fonctions de mise à jour des données                            |
//+------------------------------------------------------------------+
bool UpdateIndicatorData()
{
    bool success = true;

    success &= (CopyBuffer(h1_ema21_handle, 0, 0, 3, h1_ema21) == 3);
    success &= (CopyBuffer(h1_ema55_handle, 0, 0, 3, h1_ema55) == 3);
    success &= (CopyBuffer(h1_smma50_handle, 0, 0, 3, h1_smma50) == 3);
    success &= (CopyBuffer(h1_smma200_handle, 0, 0, 3, h1_smma200) == 3);
    success &= (CopyBuffer(h4_smma200_handle, 0, 0, 1, h4_smma200) == 1);
    success &= (CopyBuffer(h4_rsi_handle, 0, 0, 1, h4_rsi) == 1);

    return success;
}

//+------------------------------------------------------------------+
//| Fonctions de journalisation                                     |
//+------------------------------------------------------------------+
void InitializeLogging()
{
    string log_filename = StringFormat("HERMES_%s_%s.log",
                                     current_symbol,
                                     TimeToString(TimeCurrent(), TIME_DATE));

    log_handle = FileOpen(log_filename, FILE_WRITE | FILE_TXT);

    if(log_handle != INVALID_HANDLE)
    {
        string header = StringFormat(
            "=== HERMES v%s LOG ===\n" +
            "Symbole: %s\n" +
            "Démarrage: %s (Europe/Paris)\n" +
            "Magic Number: %d\n" +
            "========================================\n",
            HERMES_VERSION,
            current_symbol,
            TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES),
            HERMES_MAGIC
        );

        FileWriteString(log_handle, header);
        FileFlush(log_handle);
    }
}

void LogMessage(string type, string message)
{
    if(log_handle == INVALID_HANDLE)
        return;

    string log_entry = StringFormat("[%s] %s: %s\n",
                                  TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES),
                                  type,
                                  message);

    FileWriteString(log_handle, log_entry);
    FileFlush(log_handle);
}

void LogBlockage(SignalResult signals, FilterResult filters)
{
    string blockage_log = StringFormat(
        "=== ENTRÉE BLOQUÉE ===\n" +
        "Signaux actifs: %s\n" +
        "Direction: %s\n" +
        "Bloqué par: %s\n" +
        "Contexte: %s\n" +
        "Heure: %s (Europe/Paris)",
        signals.active_signals,
        (signals.direction > 0) ? "LONG" : "SHORT",
        filters.blocked_by,
        filters.context_data,
        TimeToString(GetParisTime(), TIME_DATE | TIME_MINUTES)
    );

    Print(blockage_log);
    LogMessage("BLOCKED", blockage_log);
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires diverses                                  |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM: return "Programme arrêté";
        case REASON_REMOVE: return "EA retiré du graphique";
        case REASON_RECOMPILE: return "EA recompilé";
        case REASON_CHARTCHANGE: return "Changement de graphique";
        case REASON_CHARTCLOSE: return "Graphique fermé";
        case REASON_PARAMETERS: return "Paramètres modifiés";
        case REASON_ACCOUNT: return "Changement de compte";
        default: return "Raison inconnue";
    }
}

void SendAlert(string message)
{
    if(enable_email_alerts)
        SendMail("HERMES Alert", message);

    if(enable_push_notifications)
        SendNotification(message);

    if(enable_sound_alerts)
        PlaySound(SOUND_ENTRY);
}
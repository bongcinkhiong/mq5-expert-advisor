//+------------------------------------------------------------------+
//|                                    Stochastic_MA_EA.mq5          |
//|                                  Copyright 2026, René Balke Style|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.00"

// --- Include library trade bawaan MT5 untuk eksekusi order ---
#include <Trade\Trade.mqh>
CTrade trade;

// --- Input Parameter (Bisa diatur dari Strategy Tester) ---
input group "=== Indicator Inputs =="
input ENUM_TIMEFRAMES   InpStockTimeframe = PERIOD_H1;     // Timeframe Stochastic
input int               InpStockK         = 5;             // Stochastic %K
input int               InpStockD         = 3;             // Stochastic %D
input int               InpStockSlowing   = 3;             // Stochastic Slowing
input double            InpStockUpper     = 80.0;          // Batas Overbought
input double            InpStockLower     = 20.0;          // Batas Oversold

input ENUM_TIMEFRAMES   InpMATimeframe    = PERIOD_D1;     // Timeframe Moving Average
input int               InpMAPeriod       = 100;           // Periode Moving Average
input ENUM_MA_METHOD    InpMAMethod       = MODE_SMA;      // Metode Moving Average

input group "=== Trading Inputs =="
input double            InpLotSize        = 0.1;           // Ukuran Lot
input int               InpTPDistance     = 100;           // Take Profit (Points)
input int               InpSLDistance     = 100;           // Stop Loss (Points)
input bool              InpUseMAFilter    = true;          // Gunakan Filter MA Tren?

// --- Variabel Global untuk Handle Indikator & Manajemen Bar ---
int handle_stoch;
int handle_ma;
datetime last_bar_time;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Inisialisasi Indikator Stochastic
   handle_stoch = iStochastic(_Symbol, InpStockTimeframe, InpStockK, InpStockD, InpStockSlowing, MODE_SMA, STO_LOWHIGH);
   if(handle_stoch == INVALID_HANDLE)
   {
      Print("Gagal membuat handle Stochastic!");
      return(INIT_FAILED);
   }

   // 2. Inisialisasi Indikator Moving Average (Filter Tren)
   handle_ma = iMA(_Symbol, InpMATimeframe, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
   if(handle_ma == INVALID_HANDLE)
   {
      Print("Gagal membuat handle Moving Average!");
      return(INIT_FAILED);
   }

   last_bar_time = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Hapus handle indikator dari memori saat EA ditutup
   IndicatorRelease(handle_stoch);
   IndicatorRelease(handle_ma);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Cek Bar Baru (Agar eksekusi hanya 1 kali di awal candle baru) ---
   datetime current_bar_time = iTime(_Symbol, InpStockTimeframe, 0);
   if(current_bar_time == last_bar_time) return; // Kalau masih di bar yang sama, hentikan
   
   // Ambil data array untuk indikator (Minimal butuh 2 index: index 0 dan index 1)
   double stoch_values[];
   double ma_values[];
   
   ArraySetAsSeries(stoch_values, true);
   ArraySetAsSeries(ma_values, true);
   
   // Copy buffer data dari indikator ke dalam array
   if(CopyBuffer(handle_stoch, 0, 0, 2, stoch_values) <= 0) return;
   if(CopyBuffer(handle_ma, 0, 0, 1, ma_values) <= 0) return;

   // Definisikan nilai Stochastic saat ini (index 1) dan sebelumnya (index 2 / atau 0 sesuai struktur)
   // Berdasarkan video, kita cek persilangan/kondisi di level 20 dan 80
   double stoch_current = stoch_values[0];
   double stoch_previous = stoch_values[1];
   double ma_value = ma_values[0];

   // Ambil harga Bid & Ask terkini serta harga Close bar sebelumnya
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // --- Logika Sinyal Sell ---
   // Stochastic turun dari atas level 80
   bool condition_sell = (stoch_previous > InpStockUpper && stoch_current <= InpStockUpper);
   if(InpUseMAFilter) {
      // Filter tambahan: Harga harus di bawah MA jika filter aktif
      condition_sell = condition_sell && (bid < ma_value);
   }

   // --- Logika Sinyal Buy ---
   // Stochastic naik dari bawah level 20
   bool condition_buy = (stoch_previous < InpStockLower && stoch_current >= InpStockLower);
   if(InpUseMAFilter) {
      // Filter tambahan: Harga harus di atas MA jika filter aktif
      condition_buy = condition_buy && (ask > ma_value);
   }

   // --- Eksekusi Order (Hanya jika belum ada posisi terbuka) ---
   if(PositionsTotal() == 0)
   {
      if(condition_sell)
      {
         double sl = bid + (InpSLDistance * _Point);
         double tp = bid - (InpTPDistance * _Point);
         trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "StochMA Sell");
         last_bar_time = current_bar_time; // Update bar agar tidak eksekusi ganda
      }
      else if(condition_buy)
      {
         double sl = ask - (InpSLDistance * _Point);
         double tp = ask + (InpTPDistance * _Point);
         trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "StochMA Buy");
         last_bar_time = current_bar_time; // Update bar agar tidak eksekusi ganda
      }
   }
}
//+------------------------------------------------------------------+
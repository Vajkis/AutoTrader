#property strict
#define RGB(r, g, b) ((color)(((b)<<16)+((g)<<8)+(r)));

double MACD_BUY_THRESHOLD = -1;
double MACD_SELL_THRESHOLD = 1;
double MACD_MIN_TOLERANCE = 0.2;
double MACD_MAX_TOLERANCE = 0.5;
double VOLUME_MIN = 0.01;
double VOLUME_MAX = 0.5;
int SLIPPAGE = 3;
double STOP_LOSS = 0;
double TAKE_PROFIT = 0;
double SAFE_STOP_LOSS_MIN = 0.5;
int MAX_SPREAD = 10;
color COLOR_LONG = RGB(69, 249, 69);
color COLOR_SHORT = RGB(244, 67, 68);

int ticket = 0;
double openMACD = 0;
double profit = 0;

int OnInit()
{
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{   
  if(ticket > 0 && OrderSelect(ticket, SELECT_BY_TICKET))
  {
    double closingPrice = OrderType() == OP_BUY ? Bid : Ask;
    double lots = OrderLots();
    OrderClose(ticket, lots, closingPrice, SLIPPAGE, clrNONE);
  }
}

void OnTick()
{
  double MACD1 = iMACD(NULL, PERIOD_M1, 15, 30, 5, PRICE_OPEN, MODE_MAIN, 2);
  double MACD2 = iMACD(NULL, PERIOD_M1, 15, 30, 5, PRICE_CLOSE, MODE_MAIN, 1);
  double MACD3 = iMACD(NULL, PERIOD_M1, 15, 30, 5, PRICE_CLOSE, MODE_MAIN, 0);

  double ATR = iATR(NULL, PERIOD_M1, 15, 0);
  double dynamicTolerance = MathMax(ATR * 0.2, MACD_MIN_TOLERANCE);
  dynamicTolerance = MathMin(dynamicTolerance, MACD_MAX_TOLERANCE);

  double dynamicSafeStopLoss = MathMax(ATR * 0.5, SAFE_STOP_LOSS_MIN);
  double equity = AccountEquity();
  double dynamicVolume = NormalizeDouble(equity * 0.0001, 2);  
  dynamicVolume = MathMax(dynamicVolume, VOLUME_MIN);
  dynamicVolume = MathMin(dynamicVolume, VOLUME_MAX);
  
  if(profit < 0)
  {
    double multiplier = MathRound(profit * -0.1);
    multiplier = MathMax(multiplier, 1);

    dynamicVolume *= multiplier;
    dynamicVolume = MathMax(dynamicVolume, VOLUME_MIN * 2);
    dynamicVolume = MathMin(dynamicVolume, 1);
  }
 
  int spread = (Ask - Bid) / Point;
  
  string info;

  info += "\nMACD1: " + DoubleToString(MACD1, 6);
  info += "\nMACD2: " + DoubleToString(MACD2, 6);
  info += "\nMACD3: " + DoubleToString(MACD3, 6);
  info += "\nTolerance: " + DoubleToString(dynamicTolerance * 0.2, 6);
  info += "\nSpread: " + spread;
  info += "\nSL: " + DoubleToString(dynamicSafeStopLoss, 2);
  info += "\nEquity: " + equity;
  info += "\nVolume: " + dynamicVolume;
  info += "\nLast Loss: " + DoubleToString(profit, 2);
  
  Comment(info);

  if(ticket > 0  && !OrderSelect(ticket, SELECT_BY_TICKET))
  {
    ticket = 0;
  }
  else if(ticket <= 0 
       && spread < MAX_SPREAD
       && MathAbs(MACD2 - MACD3) > dynamicTolerance * 0.2)
  {
    if(MACD2 < MACD_BUY_THRESHOLD 
    && MACD3 > MACD1 
    && MACD3 > MACD2
    && (Close[2] - Open[2] > 0
    || Close[1] - Open[1] > 0
    || Close[0] - Open[0] > 0))
    {
      OpenOrder(OP_BUY, dynamicVolume, Ask);
      openMACD = MACD3;
    }
    else if(MACD2 > MACD_SELL_THRESHOLD 
         && MACD3 < MACD1 
         && MACD3 < MACD2         
         && (Close[2] - Open[2] < 0
         || Close[1] - Open[1] < 0
         || Close[0] - Open[0] < 0))
    {
      OpenOrder(OP_SELL, dynamicVolume, Bid);
      openMACD = MACD3;
    }
  }
  else if(OrderSelect(ticket, SELECT_BY_TICKET))
  {
    double entryPrice = OrderOpenPrice();
    double lots = OrderLots();

    double stopLoss = OrderStopLoss();
    double newStopLoss = 0;

    if(stopLoss == 0){
      if(OrderType() == OP_BUY 
      && Bid - entryPrice > dynamicSafeStopLoss * 0.5)
      {
        newStopLoss = entryPrice + dynamicSafeStopLoss * 0.5;
        OrderModify(ticket, entryPrice, newStopLoss, 0, 0, COLOR_LONG);
      }
      else if(OrderType() == OP_SELL 
           && entryPrice - Ask > dynamicSafeStopLoss * 0.5)
      {
        newStopLoss = entryPrice - dynamicSafeStopLoss * 0.5;
        OrderModify(ticket, entryPrice, newStopLoss, 0, 0, COLOR_SHORT);
      }
    }
    
    if(OrderType() == OP_BUY 
                   && (MACD3 < MACD2 
                   || openMACD - MACD3 > dynamicTolerance 
                   || MACD2 - MACD3 > dynamicTolerance))
    {
      profit += OrderProfit();
      profit = MathMin(profit, 0);
      OrderClose(ticket, lots, Bid, SLIPPAGE, clrNONE);
      ticket = 0;
    }
    else if(OrderType() == OP_SELL 
                        && (MACD3 > MACD2 
                        || MACD3 - openMACD > dynamicTolerance 
                        || MACD3 - MACD2 > dynamicTolerance))
    {
      profit += OrderProfit();
      profit = MathMin(profit, 0);
      OrderClose(ticket, lots, Ask, SLIPPAGE, clrNONE);
      ticket = 0;
    }
  }
}

void OpenOrder(int cmd, double dynamicVolume, double price )
{
  ticket = OrderSend(Symbol(), cmd, dynamicVolume, price, SLIPPAGE, STOP_LOSS, TAKE_PROFIT, NULL, 0, 0, cmd == OP_BUY ? COLOR_LONG : COLOR_SHORT); 
}

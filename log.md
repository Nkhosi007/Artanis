## portfolio class
v1.1
### issue1

Can't compute the status if net position is not zeros
Expired-options-settling orders should be derived from net position instead of _ordersLog_

### issue1 - fix1

08/01/2016

1. seperate _ordersLog_ and _netPosition_
2. now _ordersLog_ contains all orders ever placed
3. _netPosition_ stores the current holdings
4. _settleExpiredOptions_ will derive _expiredOrders_ from _netPosition_
5. change the name of _getStatus_ to _excute_
6. _excute_ updates the _netPosition_ by iterating through the orders of the _currentDay_

### issue1 - fix2

08/02/2016

1. remove _ordersLog_, there are only _pendingOrders_ and _excutedOrders_ now
2. _settleExpiredOptions()_ no longer automatically call _markToMarket()_ anymore, bc MTM is not always available due to data
3. _genVIX()_ is now part of _portfolio_ class

## portfolio class
v2.0 update
### update 2.0

1. _policy()_ now takes two parameters and pass them to _pctHighFilter_ and _pctLowFilter_
When VIX is ranked higher than _pctHighFilter_, generates an IronCondor;
When VIX is ranked lower than _pctLowFilter_, generates an reversed IronCondor;

2. fix the bug that sometimes _policy()_ generates IC orders with correct strike prices but wrong long/short positions
3. _policy()_ now check whether the whole IC combo is available in the market and if not, cancle the whole IC
4. _markToMarket()_ works with 'try... catch...', bc of data
5. _settleExpiredOptions()_ tries settling options that expire in less than 2 days
6. _settleExpiredOptions()_ checks whether each position-closing order is available in the market and if not, cancle that order
(This might leads to unexcercised options in _netPosition_)

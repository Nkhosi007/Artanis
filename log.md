## portfolio class

### issue1

Can't compute the status if net position is not zeros
Expired-options-ettling orders should be derived from net position instead of _ordersLog_

### issue1 - fix1

08/01/2016

1. seperate _ordersLog_ and _netPosition_
2. now _ordersLog_ contains all orders ever placed
3. _netPosition_ stores the current holdings
4. _settleExpiredOptions_ will derive _expiredOrders_ from _netPosition_
5. change the name of _getStatus_ to _excute_
6. _excute_ updates the _netPosition_ by iterating through the orders of the _currentDay_
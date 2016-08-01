# Options trading strategy backtest module
	
_This is a backtest module disigned for options only_
_Language: Matlab (yeah yeah yeah, it's not a real language, I get it)_
_Author: Jerry Wong_
_Aug-2016_
	
## Basic functions and classes:

### genVIX:
* compute an analog of VIX for a specific stock
* requires options historical data

### portfolio (handle class)
#### properties
* mktInfo: current available options and info
* cash: $$$$$$$
* options: record of current position
* order history: log of orders ever placed
* activeOrders: output of the strategy

#### methods
* genVIX(): compute the genVIX for this stock
* policy(): trading strategy, output a set of orders
* settleExpiredOptions(): output a set of orders to close the position of expired options
* getStatus(): output the current holdings, gross & net profit and total fee since the first trading day

### leapyear(year): boolean function, check for leapyear

### smooth(list): compute the mid point of every two adjadent data point in list

### zeroFilter(mktInfo): remove the options with 0 bid price
	
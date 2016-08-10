
%======================Uncomment this part only at first run=============

% load('optionsSPY.mat'); 
% date = unique(optionsSPY(:,4));
% c_yahoo = yahoo;
% c_fed = fred('https://research.stlouisfed.org/fred2/');
% p0List = flip(fetch(c_yahoo,'SPY','Close',datestr(date(1)),datestr(date(end))));
% rfList = fetch(c_fed,'TB4WK',datestr(date(1)),datestr(date(end)));
%==================================END===================================

dbstop if error;

% local historical data looks like this:
% Date  Put/Call  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE /end
% 1       2      3   4    5   6    7    8    9   10    11  12   /end

% net position looks like this:
% Put/Call  K  Exp  position  IV  Delta  Gross  Fee  Net /end
%   1      2   3      4      5     6      7     8    9   /end

% An order looks like this:
% Date  Put/Call  K    Exp   XX   bid   ask   mid   IV    Delta   F   DTE  Long Short limitOrder mktOrder midOrder GrossFlow Fee NetFlow   /end
% 1       2      3      4     5    6     7     8     9    10     11    12   13   14       15        16       17        18     19   20      /end    

% back test from the 301th day till the end of historical data
% (data before 301th day is massy)
window = 301:size(date,1);

 % initiate an instance
pfl = portfolio();

% Backtest mode: 
% 'Offline': historical data is loaded from local memory
% 'Online': historical data is fetch from servers in every loop. It helps
% to assure no future data is used but significantly increase run time.
pfl.fetchMode = 'Offline'; 

% If using offline backtest mode, assign the local data set
pfl.p0List = p0List; % underlying asset prices
pfl.rfList = rfList.Data; % riskfree rate

% Set default order type in order excutions and mark-to-market evaluation
pfl.setOrderType('MD');

% Maximum buying power in terms of numbers of options
% 40 means 10 sets of IronCondor at most
pfl.orderLimit = 40;

% Set percentile ranking threshold for triggering the policy
    
    % Examples:
    % By default, high filter:=50, low filter:= 0. Which means when VIX is
    % ranked higher than 50%, long a iron condor. No reversed iron condor.
    
    % If pctHighFilter = 25, pctLowFilter = 25, that means when VIX is ranked
    % lower than 25, short a iron condor.
    
pfl.pctHighFilter = 50;
pfl.pctLowFilter = 0;
netWorthRec = zeros(1,window(end));

%grid search
comparedPar = {};
comparedRec = [];
comparedMDD = [];
hfilterList = [0,10,25,50,];
lfilterList = [50,25,10,0,];
for hfilter = hfilterList
    for lfilter = lfilterList
        if hfilter == 0 && lfilter == 0
            continue;
        end
tic;
for i = window
    % move to day i
    day = date(i);
    
    % feed day i's market data to the instance
    mktInfo = optionsSPY(optionsSPY(:,1)==day,:);
    pfl.getMktInfo(mktInfo);
    
    % compute VIX, run IronCondor strategy
    pfl.computeVIX();
    pfl.policy(hfilter,lfilter);
    
    % scan for about-to-expired options and close positions
    pfl.settleExpiredOptions();
    
    % both policy() and settleExpiredOptions() generates orders and put
    % them in pendingOrders, excute() will finish the job
    pfl.excute();
    
    % due to data insufficiency, markToMarket() is not always possible, so
    % TRY~
%     try
    pfl.markToMarket();
        
%     catch
%     end
    
    % Store the net worth of total asset in a vector
    netWorthRec(i) = pfl.netWorth;
    
    % compute maximum draw down
    maxDrawDown = maxdrawdown(netWorthRec(1:i),'arithmetic');
    
    clc;
    disp(['Backtest Process: ',num2str(100*(i-window(1))/range(window)),'%']);
    disp(datestr(date(i)));
    disp([' Net Worth of total asset: ',num2str(pfl.netWorth)]);
    disp([' Cash (relized net profit): ',num2str(pfl.cash)]);
    disp([' Market Value of option basket: ',num2str(pfl.portfolioMarketValue)]);
    disp([' Max Draw Down: ', num2str(maxDrawDown)]);
    
end
toc;

% plot(netWorthRec(window(1):end));
excutedOrders = pfl.excutedOrders;
fmt = 'yyyymmdd';

% file name tells the parameters of a backtest
% Example:
% 'backtest_SPY_20090715_20151103_bp-40_H50L0_20160809145628'
% * This is a backtest result on SPY options
% * From 07/15/2009 to 11/03/2015
% * Maximum buying power is 40 options at most
% * High percentile threshold is set at 50%
% * Low percentile threshold is set at 0%
% * This file is created at 08/09/2016 14:56:28
fileName = ['backtest_',pfl.symbol,'_',datestr(date(window(1)),fmt),'_',datestr(date(window(end)),fmt),'_','bp-',num2str(pfl.orderLimit),'_H',num2str(pfl.pctHighFilter),'L',num2str(pfl.pctLowFilter),'_',datestr(now,'yyyymmddHHMMSS')];
save(fileName,'netWorthRec','excutedOrders');
comparedPar = cat(1,comparedPar,[num2str(hfilter),'-',num2str(lfilter)]);
comparedRec = cat(1,comparedRec,netWorthRec);
comparedMDD = cat(2,comparedMDD,maxDrawDown);
pfl.reset();
    end
end

save('gridSearch.mat','comparedRec','window','comparedPar','comparedMDD')


figure;
subplot(2,2,1); hold on;
for i = 1:size(comparedRec,1)
    plot(comparedRec(i,window));
end
legend(comparedPar,'Location','West');
title('ALL');

subplot(2,2,2); hold on;
head = [1:3,7,11,15];
for i = 1:size(comparedRec(head,:),1)
    plot(comparedRec(head(i),window));
end
legend(comparedPar(head),'Location','West');
title('One side Iron Condor');

subplot(2,2,3); hold on;
head = [4:6,8:10,12:14];
for i = 1:size(comparedRec(head,:),1)
    plot(comparedRec(head(i),window));
end
legend(comparedPar(head),'Location','West');
title('Two side Iron Condor');

subplot(2,2,4); hold on;
head = [6,9,12];
for i = 1:size(comparedRec(head,:),1)
    plot(comparedRec(head(i),window));
end
legend(comparedPar(head),'Location','West');
title('Symetric Iron Condor');

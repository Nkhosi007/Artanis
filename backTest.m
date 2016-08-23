
%======================Uncomment this part only at first run=============
format longg;
try
date = unique(optionsSPY(:,1));
catch
load('optionsSPY.mat');
date = unique(optionsSPY(:,1));
end

try
  load('p0List_SPY.mat');
catch
  c_yahoo = yahoo;
  p0List = flip(fetch(c_yahoo,'SPY','Close',datestr(date(1)),datestr(date(end))));
end

try
  load('rfList_SPY.mat');
catch
  c_fed = fred('https://research.stlouisfed.org/fred2/');
  rfList = fetch(c_fed,'TB4WK',datestr(date(1)),datestr(date(end)));
end
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
st = 300;
window = st:size(date,1);

% initiate an instance
pfl = portfolio();

% Backtest mode: 
% 'Offline': historical data is loaded from local memory
% 'Online': historical data is fetch from servers in every loop. It helps
% to assure no future data is used but significantly increases run time.
pfl.fetchMode = 'Offline'; 
pfl.setFetchMode('offline',p0List,rfList.Data);

% If using offline backtest mode, assign the local data set
%pfl.p0List = p0List; % underlying asset prices
%pfl.rfList = rfList.Data; % riskfree rate

% Set default order type in order excutions and mark-to-market evaluation
pfl.setOrderType('MiddlePrice');

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
comparedNet = [];
comparedMDD = [];
db_VIXFlag = zeros(1,window(end));
db_policyFlag = zeros(1,window(end));
db_MTMFlag = zeros(1,window(end));
db_VIX = zeros(1,window(end));
db_premiumFlag = zeros(1,window(end));
db_pctUp = zeros(1,window(end));
db_pctDwn = zeros(1,window(end));
db_price = zeros(1,window(end));
% cmp_VIXFlag = [];
% cmp_policyFlag = [];
% cmp_MTMFlag = [];
hfilterList = [25,];
lfilterList = [0,];
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
    db_VIXFlag(i) = pfl.VIXFlag;
    db_policyFlag(i) = pfl.policyFlag;
    db_MTMFlag(i) = pfl.MTMFlag;
    db_VIX(i) = pfl.VIX;
    db_premiumFlag(i) = pfl.premiumFlag;
    db_pctUp(i) = pfl.pctUp;
    db_pctDwn(i) = pfl.pctDwn;
    db_price(i) = pfl.p0;
    
    % compute maximum draw down
    dstMat = repmat(netWorthRec(1,st:i),i-st+1,1);
    drawDownMat = tril(dstMat-dstMat');
    maxDrawDown = max(max(drawDownMat));
    

    
%     maxDrawDown = maxdrawdown([0,netWorthRec(1:i)],'arithmetic');
    
    clc;
    disp(['Backtest Process: ',num2str(100*(i-window(1))/range(window)),'%']);
    disp(['Start date: ',datestr(date(window(1)))]);
    disp(['End date: ',datestr(date(i))]);
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

% fileName = ['backTestResults\backtest_',pfl.symbol,'_',datestr(date(window(1)),fmt),'_',datestr(date(window(end)),fmt),'_','bp-',num2str(pfl.orderLimit),'_H',num2str(pfl.pctHighFilter),'L',num2str(pfl.pctLowFilter),'_',datestr(now,'yyyymmddHHMMSS')];
% save(fileName,'netWorthRec','excutedOrders');
comparedPar = cat(1,comparedPar,[num2str(hfilter),'-',num2str(lfilter)]);
comparedNet = cat(1,comparedNet,netWorthRec);
comparedMDD = cat(2,comparedMDD,maxDrawDown);
% pfl.reset();
    end
end

% save('gridSearch.mat','comparedRec','window','comparedPar','comparedMDD')

% 
% figure;
% subplot(2,2,1); hold on;
% for i = 1:size(comparedRec,1)
%     plot(comparedRec(i,window));
% end
% legend(comparedPar,'Location','West');
% title('ALL');
% 
% subplot(2,2,2); hold on;
% head = [1:3,7,11,15];
% for i = 1:size(comparedRec(head,:),1)
%     plot(comparedRec(head(i),window));
% end
% legend(comparedPar(head),'Location','West');
% title('One side Iron Condor');
% 
% subplot(2,2,3); hold on;
% head = [4:6,8:10,12:14];
% for i = 1:size(comparedRec(head,:),1)
%     plot(comparedRec(head(i),window));
% end
% legend(comparedPar(head),'Location','West');
% title('Two side Iron Condor');
% 
% subplot(2,2,4); hold on;
% head = [6,9,12];
% for i = 1:size(comparedRec(head,:),1)
%     plot(comparedRec(head(i),window));
% end
% legend(comparedPar(head),'Location','West');
% title('Symetric Iron Condor');

    dstMat = repmat(netWorthRec(1,st:i),i-st+1,1);
    drawDownMat = tril(dstMat-dstMat');
    maxDrawDown = max(max(drawDownMat));




figure();
subplot(10,1,[1;2;3]);
hold on;
plot(date(window),[netWorthRec(window);[0,diff(netWorthRec((window)))]]);
set(gca,'XTick',[]);
legend({'Net Worth','Net Worth Change'},'Location','NorthWest');
plot(date(window),zeros(1,size(window,2)),'k--');
title([num2str(pfl.pctHighFilter),'-',num2str(pfl.pctLowFilter)]);
[blackSheep(1),blackSheep(2)] = find(drawDownMat==maxDrawDown,1);
MDDX = date(st+blackSheep(2)-1); MDDY = netWorthRec(st+blackSheep(1)-1);
MDDPos = [date(st+blackSheep(2)-1), netWorthRec(st+blackSheep(1)-1),date(st+blackSheep(1)-1)-date(st+blackSheep(2)-1),maxDrawDown];
rectangle('Position',MDDPos,'LineStyle','-.');
text(MDDX,MDDY+2,['Max Draw-down: ',num2str(maxDrawDown)]);
axis tight;

subplot(10,1,4);
bar(date(window),db_VIXFlag(window));
set(gca,'XTick',[]);
set(gca,'YTick',[]);
title('VIX');
axis tight;

subplot(10,1,5);          
bar(date(window),db_policyFlag(window));
set(gca,'XTick',[]);
set(gca,'YTick',[]);
title('Policy');
axis tight;

subplot(10,1,6);
bar(date(window),db_MTMFlag(window));
set(gca,'XTick',[]);
set(gca,'YTick',[]);
title('MarkToMarket');
axis tight;

subplot(10,1,[7,8]);
% bar(db_premiumFlag);
plot(db_price(window));
set(gca,'XTick',[]);
set(gca,'YTick',[]);
% title('If premium <-1');
title([pfl.symbol,' Price']);
% axis tight;

subplot(10,1,[9,10]);
hold on;
plot(date(window),db_VIX(window));
plot(date(window),db_pctUp(window));
plot(date(window),db_pctDwn(window));
datetick('x','yy-mm');
set(gca,'YTick',[]);
title('VIX');
axis tight;
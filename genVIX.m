 %Date  Put/Call  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE
% 1       2      3   4    5   6    7    8    9   10    11  12

% load the data if needed
% load('optionsSPY.mat'); 
% date = unique(optionsSPY(:,1));

%fetch close price for the the underlying stock
% c_yahoo = yahoo;
% c_fed = fred('https://research.stlouisfed.org/fred2/');
% p0List = flip(fetch(c_yahoo,'SPY','Close',datestr(date(1)),datestr(date(end))));
% rfList = fetch(c_fed,'TB4WK',datestr(date(1)),datestr(date(end)));

%Only part of the data is available for VIX calculation
window = 1:size(date,1);

disp('----------------------Begin----------------------');
tic;
%Compute VIX for one day in each iteration and store it in VIXlist
VIXlist = [];
for i = window %Only compute the VIX for the time window we concern
currentTerm = date(i);

format longG;

%Condition of picking valid options for computation
condition = optionsSPY(:,1)==currentTerm & ...
    optionsSPY(:,12)>23 & optionsSPY(:,12)<37;

data = optionsSPY(condition,:);

if size(data,1)<1
    continue
end

%Close price for the underlying asset in current iteration
p0 = p0List(i,2);

%date(13)


%Expiration of near term and next term
%(usually there are only two options with DTEs between(23-37 days)
nearTermExpiration = min(data(:,4));
nextTermExpiration = max(data(:,4));


%Compute Time and Date
[year,M,D,H,MN,S] = datevec(datetime('today')); 

yearMin = 60*24*366;

%Minutes left in current day
Mc = datevec(datetime('tomorrow')-datetime('today'))*[0;0;0;60;1;1/60];

%Mintues in expiration day
if week(datetime(datevec(nearTermExpiration)),'weekofmonth') == 3
    % Standard 3rd friday options: Ms = mins from midnight to 8:30 am
    Ms1 = 510;
else
    % weekly friday options: Ms = mins from midnight to 3:00 pm
    Ms1 = 900;
end

if week(datetime(datevec(nextTermExpiration)),'weekofmonth') == 3
    Ms2 = 510;
else
    Ms2 = 900;
end

%Minutes in the days between current day and expiration day (exclusive)
Mo1 = (nearTermExpiration - currentTerm)*60*24;
Mo2 = (nextTermExpiration - currentTerm)*60*24;

%Minutes to expirations for near term options(1) and next term options(2)
T1 = (Mc+Ms1+Mo1)/yearMin;
T2 = (Mc+Ms2+Mo2)/yearMin;


%This is the strike prices list of near term and next term options
klist1 = unique(data(data(:,4)==nearTermExpiration,3));
klist2 = unique(data(data(:,4)==nextTermExpiration,3));

%Extract the nearet term table and next term table
nearTerm = [klist1,data(data(:,2)==1&data(:,4)==nearTermExpiration,8),...
    data(data(:,2)==2&data(:,4)==nearTermExpiration,[8,11])];
nearTerm = [nearTerm,nearTerm(:,2)-nearTerm(:,3)];

nextTerm = [klist2,data(data(:,2)==1&data(:,4)==nextTermExpiration,8),...
    data(data(:,2)==2&data(:,4)==nextTermExpiration,[8,11])];
nextTerm = [nextTerm,nextTerm(:,2)-nextTerm(:,3)];

%which [strike price to pick,difference between call/put] in step1
tmp1 = nearTerm(abs(nearTerm(:,end))==min(abs(nearTerm(:,end))),[1,end]);
tmp2 = nextTerm(abs(nextTerm(:,end))==min(abs(nextTerm(:,end))),[1,end]);

%kf : striKe price used to compute Forward price
%dp : Difference between call and put prices for a specify kf
%f : Forward price (Forward level as in the VIX white paper)
%k : striKe price imediately lower than the Forward level
kf1 = tmp1(1,1);
dp1 = tmp1(1,2);
f1 = nearTerm(nearTerm(:,1) == kf1,4);
k1 = max(klist1(klist1<f1));
if size(k1,1)==0
    k1 = min(klist1);
end

kf2 = tmp2(1,1);
dp2 = tmp2(1,2);
f2 = nextTerm(nextTerm(:,1) == kf2,4);
k2 = max(klist2(klist2<f2));
if size(k2,1)==0
    k2 = min(klist2);
end

%Risk free rate

closestFriday1 = max(rfList.Data(rfList.Data(:,1)<nearTermExpiration,1));
closestFriday2 = max(rfList.Data(rfList.Data(:,1)<nextTermExpiration,1));
rf1 = rfList.Data(rfList.Data(:,1)==closestFriday1,2);%1.1625/100;%log(f1/p0)/T1;%log((f1-kf1)/dp1)/T1;
rf2 = rfList.Data(rfList.Data(:,1)==closestFriday2,2);%1.1625/100;%log(f2/p0)/T2;%log((f2-kf2)/dp2)/T2;

%table1 and table2 are the tables on page 8 of VIX white paper
%midPrice here means the average of the call/put price
midPrice1 = 0.5*data(data(:,2)==2&data(:,3)==k1&data(:,4)==nearTermExpiration,[8,6])...
    +0.5*data(data(:,2)==1&data(:,3)==k1&data(:,4)==nearTermExpiration,[8,6]);
putTable1 = zeroFilter(data(data(:,2)==2&data(:,3)<k1&data(:,4)==nearTermExpiration,[3,8,6]),'put');
callTable1 = zeroFilter(data(data(:,2)==1&data(:,3)>k1&data(:,4)==nearTermExpiration,[3,8,6]),'call');
table1 = [putTable1;[k1,midPrice1];callTable1];

midPrice2 = 0.5*data(data(:,2)==2&data(:,3)==k2&data(:,4)==nextTermExpiration,[8,6])...
    +0.5*data(data(:,2)==1&data(:,3)==k2&data(:,4)==nextTermExpiration,[8,6]);
putTable2 = zeroFilter(data(data(:,2)==2&data(:,3)<k2&data(:,4)==nextTermExpiration,[3,8,6]),'put');
callTable2 = zeroFilter(data(data(:,2)==1&data(:,3)>k2&data(:,4)==nextTermExpiration,[3,8,6]),'call');
table2 = [putTable2;[k2,midPrice2];callTable2];

%insert columns of smoothed delta-strike (dK) price at the second column
table1 = [table1(:,1),smooth(table1(:,1)),table1(:,2:end)];
table2 = [table2(:,1),smooth(table2(:,1)),table2(:,2:end)];

%in table1 and table2, this is the format:
% column: 1   2      3        4(useless from here)
%         K  dK  mid-quote   bid

%vol of near term and next term options
sigmaSquare1 = 2*exp(rf1*T1)/T1*...
    (table1(:,2)./table1(:,1).^2)'*table1(:,3)-...
    1/T1*(f1/k1-1)^2;

sigmaSquare2 = 2*exp(rf2*T2)/T2*...
    (table2(:,2)./table2(:,1).^2)'*table2(:,3)-...
    1/T2*(f2/k2-1)^2;

%minutes between now and the expiration
dt1 = datetime(datevec(nearTermExpiration))-datetime(datevec(currentTerm));
NT1 = datevec(dt1)*[0;0;60*24;60;1;1/60]+Mc;
dt2 = datetime(datevec(nextTermExpiration))-datetime(datevec(currentTerm));
NT2 = datevec(dt2)*[0;0;60*24;60;1;1/60]+Mc;

%minutes in a 30-days month and a 365-days year
N30 = 43200;
N365 = 525600;


if nearTermExpiration==nextTermExpiration
    
    %if we have only one valid option(23<DTE<37), we just use that one
    VIX = 100*sqrt((T1*abs(sigmaSquare1))*N365/N30);
else
    %if we have two valid options(23<DTE<37), we average them
    VIX = 100*sqrt((T1*abs(sigmaSquare1)*(NT2-N30)/(NT2-NT1)+T2*abs(sigmaSquare2)*(N30-NT1)/(NT2-NT1))*N365/N30);
end

% disp(currentTerm);
% disp(VIX);
%store VIX in a list for plotting purpose
VIXlist(i,:) = [currentTerm,VIX];
end

VIXlist(VIXlist(:,2)==0,2)=NaN;

% If you want to compare the result with the official data
% run the code below
%------------------------------
% [VIX_CBOE,DATE_CBOE] = xlsread('vixcurrent(CBOE).xlsx');
% VIX_CBOE = [datenum(DATE_CBOE),VIX_CBOE];
% cmp1 = VIX_CBOE(ismember(VIX_CBOE(:,1),date(window)),5);
% err = VIXlist(window,2)-cmp1;
% % subplot(1,2,1);
% hold on;
% plot(VIXlist(window,2)); plot(cmp1);
% % subplot(1,2,2);
% % hold on;
% plot(err);
% legend({'Computed VIX','True VIX','Error'});
% Rsquare = 1-var(err(~isnan(err)))/var(cmp1(~isnan(err)));
%-------------------------------
runTime = toc;
disp(['Timeframe: ',datestr(date(window(1))),' TO ',datestr(date(window(end)))]);
disp(['Time consumed: ',num2str(runTime),' secs']);
% disp(['Rsquare: ',num2str(Rsquare*100),'%']);
disp('-----------------------End-----------------------');
% Date  C(1)/P(2)  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE
% 1        2       3   4    5   6    7    8    9   10    11  12
% format longG
classdef portfolio < handle
    properties
        currentDay;
        oldMktInfo; %only for testing
        mktInfo;
        symbol = 'SPY';
        fetchMode = 'Offline';
        p0;
        p0List;
        rf;
        rfList;
        orderLimit=20;
        VIX;
        VIXlog = [];
        VIXFlag = 1;
        policyFlag = 0;
        premiumFlag = 0;
        MTMFlag = 1;
        ICFlag = 0;
        signalCondition;
        excutedOrders = [];
        pendingOrders = [];
        netPosition = zeros(0,10);
        cash=0;
        portfolioMarketValue=0;
        netWorth=0;
        status = [];
        orders = [];
        orderType = [0,1,0];
        activeOrders = [];
        expiredOrders = [];
        fixFee = 0;
        feeRate = 0;
        grossSum;
        feeSum;
        netSum;
        premium;
        pctHighFilter = 50;
        pctLowFilter = 0;
        pctUp = NaN;
        pctDwn = NaN;
        c_yahoo;
        c_fed;
        dataSufficiency;
    end
    
    methods
        
        function setFetchMode(self,modeStr,para1,para2)
            if nargin <3
                para1 = [];
                para2 = [];
            end
            if strcmpi(modeStr,'online')
                self.fetchMode = 'Online';
                self.c_yahoo = yahoo;
                self.c_fed = fred('https://research.stlouisfed.org/fred2/');
            elseif strcmpi(modeStr,'offline')
                self.fetchMode = 'Offline';
                self.p0List = para1;
                self.rfList = para2;
            end
        end
        
        function reset(self)
            self.cash = 0;
            self.netPosition = zeros(0,10);
        end
        
        function setOrderType(self,orderTypeStr)
            if strcmpi(orderTypeStr,'LimitOrder') || strcmpi(orderTypeStr,'LM')
                self.orderType = [1,0,0];
            elseif strcmpi(orderTypeStr,'MarketOrder') || strcmpi(orderTypeStr,'MK')
                self.orderType = [0,1,0];
            elseif strcmpi(orderTypeStr,'MiddlePrice') || strcmpi(orderTypeStr,'MD')
                self.orderType = [0,0,1];
            else
                error('Input valid order type: LimitOrder or LM, MarketOrder o  r MK, MiddleOrder or MD');
            end
        end
        
        function computeVIX(self)
            currentTerm = self.currentDay;

            %Condition of picking valid options for computation
            condition = self.mktInfo(:,1)==currentTerm & ...
                self.mktInfo(:,12)>23 & self.mktInfo(:,12)<37;
            data = self.mktInfo(condition,:);

            if size(data,1)<1
                self.VIXFlag = -1;
                self.VIX = NaN;
                self.VIXlog = cat(1,self.VIXlog,[self.currentDay,self.VIX]);
            else
                self.VIXFlag = 1;

                %Expiration of near term and next term
                %(usually there are only two options with DTEs between(23-37 days)
                nearTermExpiration = min(data(:,4));
                nextTermExpiration = max(data(:,4));


                %Compute Time and Date
    %             [year,M,D,H,MN,S] = datevec(datetime('today')); 

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
    %             dp1 = tmp1(1,2);
                f1 = nearTerm(nearTerm(:,1) == kf1,4);
                k1 = max(klist1(klist1<f1));
                if size(k1,1)==0
                    k1 = min(klist1);
                end

                kf2 = tmp2(1,1);
    %             dp2 = tmp2(1,2);
                f2 = nextTerm(nextTerm(:,1) == kf2,4);
                k2 = max(klist2(klist2<f2));
                if size(k2,1)==0
                    k2 = min(klist2);
                end

                %Risk free rate
                if strcmpi(self.fetchMode,'Online')
                    self.rf = fetch(self.c_fed,'TB4WK',datestr(currentTerm-30),datestr(currentTerm));
                    self.rf = self.rf.Data(end,2);
                elseif strcmpi(self.fetchMode,'Offline')
                    closestFriday = max(self.rfList(self.rfList(:,1)<=self.currentDay,1));
                    self.rf = self.rfList(self.rfList(:,1)==closestFriday,2);
                else
                    error('fetchMode: "Online" OR "Offline');
                end

    %             closestFriday1 = max(rflist.Data(rflist.Data(:,1)<nearTermExpiration,1));
    %             closestFriday2 = max(rflist.Data(rflist.Data(:,1)<nextTermExpiration,1));
                rf1 = self.rf; % rflist.Data(rflist.Data(:,1)==closestFriday1,2);%1.1625/100;%log(f1/p0)/T1;%log((f1-kf1)/dp1)/T1;
                rf2 = self.rf; % rflist.Data(rflist.Data(:,1)==closestFriday2,2);%1.1625/100;%log(f2/p0)/T2;%log((f2-kf2)/dp2)/T2;

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
                    self.VIX = 100*sqrt((T1*abs(sigmaSquare1))*N365/N30);
                else
                    %if we have two valid options(23<DTE<37), we average them
                    self.VIX = 100*sqrt((T1*abs(sigmaSquare1)*(NT2-N30)/(NT2-NT1)+T2*abs(sigmaSquare2)*(N30-NT1)/(NT2-NT1))*N365/N30);
                end

                self.VIXlog = cat(1,self.VIXlog,[self.currentDay,self.VIX]);
            end
            
        end
        
        function getMktInfo(self,newMktInfo)
            self.mktInfo = newMktInfo;
            self.currentDay = unique(self.mktInfo(:,1));
            self.pendingOrders = [];
            
            %Close price for the underlying asset in current iteration
                if strcmpi(self.fetchMode,'Online')
                    self.p0 = fetch(self.c_yahoo,self.symbol,'Close',datestr(currentTerm));
                    self.p0 = self.p0(:,2);
                elseif strcmpi(self.fetchMode,'Offline')
                    self.p0 = self.p0List(self.p0List(:,1)==self.currentDay,2);
                else
                    error('fetchMode: "Online" OR "Offline');
                end
            
            if size(self.p0,1) == 0
                self.p0 = 0;
            end
        end
        
        function markToMarket(self)
           
            if size(self.netPosition,1) == 0 %if we have not holdings at all
                self.MTMFlag = 1;
            
            else
                self.MTMFlag = 0;
                for i = 1:size(self.netPosition,1)
                    pointer = self.netPosition(i,[1,2,3]);
                    head = ismember(self.mktInfo(:,[2,3,4]),pointer,'rows');

                    try
                        excutePrices = [self.mktInfo(head,[6,7]);self.mktInfo(head,[7,6]);self.mktInfo(head,[8,8])];
                        longshort = sufficientStat(-self.netPosition(i,4));
                        ordersTypeVec = self.orderType;
                        self.netPosition(i,10) = -longshort*excutePrices'*ordersTypeVec';
                        self.MTMFlag = self.MTMFlag+1/size(self.netPosition,1);
                    catch
    %                     self.MTMFlag = -1;
                    end
                end
                
                % market prices are sometimes weird near expiration
                
                
            end
            
            self.portfolioMarketValue = sum(self.netPosition(:,10));
            self.netWorth = self.cash + self.portfolioMarketValue;
        end
            
        function policy(self,hfilter,lfilter)
            
            if nargin < 2
                lfilter = 0;
                if nargin < 1
                    hfilter = 50;
                end
            end
            
            self.pctHighFilter = hfilter;
            self.pctLowFilter = lfilter;
            
            % initiate activeOrders
            self.activeOrders = zeros(0,20);

            
            if self.currentDay~= self.VIXlog(end,1)
                self.computeVIX();
            end
            
            
            %                1      2   3      4      5     6      7     8    9
            %netPosition:  C1P2     K  Exp  position  IV  Delta  Gross  Fee  Net
            %policy starts here
            
            % search the most recent expiration day between 45-60
            targetExp = min(self.mktInfo(self.mktInfo(:,12)>45 & self.mktInfo(:,12)<60,4));
            
            % requirements for policy (data sufficiency requirement+buyingPower limit)
            self.dataSufficiency = size(self.VIXlog(~isnan(self.VIXlog(:,2)),2),1)>60 &&... % more than 60 historical VIXes in record
                size(targetExp,1)>0;% at least one option expires between 45-60 days
                
            if self.dataSufficiency
                self.policyFlag = -1;
            else
                self.policyFlag = 0;
            end
            
            self.signalCondition = self.dataSufficiency && sum(abs(self.netPosition(:,4)))<self.orderLimit;% &&...% less than 20 options in the basket
                %~ismember(targetExp,self.netPosition(:,3));% two IC sets must expire at different dates(15 days apart at least)
            
                
                
                
%             disp(self.signalCondition);
            
            % if data is sufficient, check VIX rank
            if self.signalCondition == 1
                validVIX = self.VIXlog(~isnan(self.VIXlog(:,2)),:);%
                self.pctUp = prctile(validVIX(end-59:end,2),100-self.pctHighFilter);
                self.pctDwn = prctile(validVIX(end-59:end,2),self.pctLowFilter);
                %                 disp(pct);
                
                %check VIX rank
                % (policy is computationally expensive, do it only when needed)
                
                if self.VIX>self.pctUp
                    self.ICFlag = 1;
                elseif self.VIX<self.pctDwn
                    self.ICFlag = -1;
                else
                    self.ICFlag = 0;
                end
                
                if  self.ICFlag ~=0;
                    %                     disp('YEAH-------------');
                    
                    % extract available strike price list
                    klist = self.mktInfo(:,3);
%                     disp(self.p0);
                    %short call
                    ka = ceil(self.p0);
%                     disp(ka)
                    %short put
                    kb = floor(self.p0);
%                     disp(kb)
                        
                    if self.ICFlag == 1
                        self.premium = -999;
                    elseif self.ICFlag == -1
                        self.premium = 999;
                    end
                    
                    while self.premium*self.ICFlag < -1
                        %long call
                        kc = ka+2;
                        %long put
                        kd = kb-2;
                        
                        pointerList = [2,kd,targetExp;...
                            2,kb,targetExp;...
                            1,ka,targetExp;...
                            1,kc,targetExp];
                        
                        ironCondor = [self.mktInfo(ismember(self.mktInfo(:,[2,3,4]),pointerList(1,:),'rows'),:);%kd long put
                            self.mktInfo(ismember(self.mktInfo(:,[2,3,4]),pointerList(2,:),'rows'),:);%kb short put
                            self.mktInfo(ismember(self.mktInfo(:,[2,3,4]),pointerList(3,:),'rows'),:);%ka short call
                            self.mktInfo(ismember(self.mktInfo(:,[2,3,4]),pointerList(4,:),'rows'),:)];%kc long call
                        
                        
                        %                     disp(size(ironCondor));
                        
                        if self.VIX > self.pctUp % high VIX -> Iron Condor
                            longShortANDorderType = cat(2,...
                                [1,0;...
                                0,-1;...
                                0,-1;...
                                1,0],...
                                repmat(self.orderType,4,1));
                        elseif self.VIX < self.pctDwn % low VIX -> reversed Iron Condor
                            longShortANDorderType = cat(2,...
                                [0,-1;...
                                1,0;...
                                1,0;...
                                0,-1],...
                                repmat(self.orderType,4,1));
                        else
                            % do nothing
                        end
                        
                        %                     disp(size(ironCondor,1));
                        if size(ironCondor,1) == 4 % sometimes IC is not available
                            self.activeOrders = [ironCondor,longShortANDorderType];
                            self.policyFlag = 1;
                            % compute gross/fee/net cashflow impact of the orders
                            for i  = 1:size(self.activeOrders,1)
                                excutePrices = [self.activeOrders(i,[6,7]);self.activeOrders(i,[7,6]);self.activeOrders(i,[8,8])];
                                longshort = self.activeOrders(i,[13,14]);
                                ordersTypeVec = self.activeOrders(i,[15,16,17]);
                                gross = -longshort*excutePrices'*ordersTypeVec';
                                fee = abs(gross)*self.feeRate+self.fixFee;
                                net = gross - fee;
                                self.activeOrders(i,18:20) = [gross,fee,net];
                            end
                        else
                            self.policyFlag = -2;
                        end
                        
                        
                        self.premium = sum(self.activeOrders(:,18));
                        if self.premium*self.ICFlag <-1
                            self.premiumFlag = 1;
                            if abs(ka-self.p0)<abs(kb-self.p0)
                                ka = min(klist(klist>ka));
                            else
                                kb = max(klist(klist<kb));
                            end
                        else
                            self.premiumFlag = 0;
                        end
                    end
                else
                    %do nothing
                    self.policyFlag = 0;
                end
                
            else
                % do nothing
                % self.policyFlag is no longer handled here
                
            end
            
            % generate orders and store them in pendingOrders
            % function excute() will handle from here
            self.pendingOrders = cat(1,self.pendingOrders,self.activeOrders);
        end
        
        function settleExpiredOptions(self)
            %excute the expired options
            expiredPosition = self.netPosition(self.netPosition(:,3)<=self.currentDay+1,:);
            self.expiredOrders = [];
            
            for i = 1:size(expiredPosition,1)
                availableOrder = self.mktInfo(ismember(self.mktInfo(:,2:4),expiredPosition(i,1:3),'rows'),:);
                if size(availableOrder,1)==0
                    continue;
                else
                    self.expiredOrders = cat(1,self.expiredOrders,[availableOrder,sufficientStat(-expiredPosition(i,4)),self.orderType, zeros(1,3)]);
                end
            end
            
%             self.expiredOrders = self.mktInfo(ismember(self.mktInfo(:,2:4),expiredPosition(:,1:3),'rows'),:);
            %                            1:12                            13,14                          15:17
%             self.expiredOrders = cat(2,self.expiredOrders, [sufficientStat(-expiredPosition(:,4)),repmat(self.orderType,size(self.expiredOrders,1),1)], zeros(size(self.expiredOrders,1),3));
            
            for i  = 1:size(self.expiredOrders,1)
                    excutePrices = [self.expiredOrders(i,[6,7]);self.expiredOrders(i,[7,6]);self.expiredOrders(i,[8,8])];
                    longshort = self.expiredOrders(i,[13,14]);
                    ordersTypeVec = self.expiredOrders(i,[15,16,17]);
                    gross = -longshort*excutePrices'*ordersTypeVec';
                    fee = abs(gross)*self.feeRate+self.fixFee;
                    net = gross - fee;
                    self.expiredOrders(i,18:20) = [gross,fee,net];
            end
            
            self.pendingOrders = cat(1,self.pendingOrders,self.expiredOrders);
            
            
        end
        
        function excute(self)
            
            % for pending orders
            if size(self.pendingOrders,1) >0
            pointerList = unique(self.pendingOrders(:,[2,3,4]),'rows');
                for j = 1:size(pointerList,1)
                    pointer = pointerList(j,:);

                    specificInfo = self.pendingOrders(ismember(self.pendingOrders(:,[2,3,4]),pointer,'rows'),:); 

                    weight = sum(specificInfo(:,[13,14]),2);
                    positionIncrement = sum(weight);
                    impliedVol = self.mktInfo(ismember(self.mktInfo(:,[2,3,4]),pointer,'rows'),9);
                    weightedDelta = specificInfo(:,10)'*weight;
                    %GFN := Gross Fee Net
                    GFNIncrement = sum(specificInfo(:,18:20),1);

                    head = ismember(self.netPosition(:,[1,2,3]),pointer,'rows');

                    if sum(head) == 1
                        self.netPosition(head,4) = self.netPosition(head,4)+positionIncrement;
                        self.netPosition(head,5) = impliedVol;
                        self.netPosition(head,6:9) = self.netPosition(head,6:9)+[weightedDelta,GFNIncrement];
                    elseif sum(head) == 0
                        self.netPosition = cat(1,self.netPosition,[pointer,positionIncrement,impliedVol,weightedDelta,GFNIncrement,0]);
                    else
                        error('check pointer');
                    end
                end
            
            %                1      2   3      4      5     6      7     8    9   10
            %netPosition: Put/Call  K  Exp  position  IV  Delta  Gross  Fee  Net MktVal
            
            self.excutedOrders = cat(1,self.excutedOrders,self.pendingOrders);
            self.cash = self.cash + sum(self.pendingOrders(:,20));
            self.pendingOrders = zeros(0,20);
            self.activeOrders = zeros(0,20);
            self.expiredOrders = zeros(0,20);
           
%             self.markToMarket();
%             self.netWorth = self.cash + self.portfolioMarketValue;
            end
            
            % for expired options
            for i = 1:size(self.netPosition,1)
                if self.netPosition(i,3) <= self.currentDay
                    self.cash = self.cash + self.netPosition(i,10);
                    self.netPosition(i,4) = 0;
                else
                    %nothing to do with not-expired options
                end
            end
            
             self.netPosition = self.netPosition(self.netPosition(:,4)~=0,:);
            
        end

 % Date  Put/Call  K    Exp   XX   bid   ask   mid   IV    Delta   F   DTE  Long Short limitOrder mktOrder midOrder GrossFlow Fee NetFlow   /end
% 1       2      3      4     5    6     7     8     9    10     11    12   13   14       15        16       17        18     19   20      /end    
       

    end
end
    
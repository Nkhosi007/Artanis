% Date  Put/Call  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE
% 1       2      3   4    5   6    7    8    9   10    11  12
% format longG
classdef portfolio < handle
    properties
        currentDay;
        oldMktInfo; %only for testing
        mktInfo;
        p0 = 210.389999;
        VIX = 22.7967654004844;
        excutedOrders = [];
        pendingOrders = [];
        netPosition = zeros(0,10);
        cash=0;
        portfolioMarketValue=0;
        netWorth=0;
        status = [];
        orders = [];
        orderType = [0,0,1];
        activeOrders = [];
        expiredOrders = [];
        fixFee = 0;
        feeRate = 1/1000;
        grossSum;
        feeSum;
        netSum;
    end
    
    methods
        
        function setOrderType(self,orderTypeStr)
            if strcmpi(orderTypeStr,'LimitOrder') || strcmpi(orderTypeStr,'LM')
                self.orderType = [1,0,0];
            elseif strcmpi(orderTypeStr,'MarketOrder') || strcmpi(orderTypeStr,'MK')
                self.orderType = [0,1,0];
            elseif strcmpi(orderTypeStr,'MiddleOrder') || strcmpi(orderTypeStr,'MD')
                self.orderType = [0,0,1];
            else
                error('Input valid order type: LimitOrder or LM, MarketOrder or MK, MiddleOrder or MD');
            end
        end
        
        function computeVIX(self)
            
        end
        
        function getMktInfo(self,newMktInfo)
            self.mktInfo = newMktInfo;
            self.currentDay = unique(self.mktInfo(:,1));
            self.pendingOrders = [];
        end
        
        function markToMarket(self)
           
            for i = 1:size(self.netPosition,1)
                pointer = self.netPosition(i,[1,2,3]);
                head = ismember(self.mktInfo(:,[2,3,4]),pointer,'rows');
                
                excutePrices = [self.mktInfo(head,[6,7]);self.mktInfo(head,[7,6]);self.mktInfo(head,[8,8])];
                longshort = sufficientStat(-self.netPosition(i,4));
                ordersTypeVec = self.orderType;
                self.netPosition(i,10) = -longshort*excutePrices'*ordersTypeVec';
            end
            
            self.portfolioMarketValue = sum(self.netPosition(:,10));
            self.netWorth = self.cash + self.portfolioMarketValue;
        end
            
        function policy(self)
            
            %policy starts here
            
            if self.VIX >19 %strategy for test-purpose
                                       % Date  Put/Call  K    Exp   XX   bid   ask   mid   IV    Delta   F   DTE  Long Short limitOrder mktOrder midOrder GrossFlow Fee NetFlow   /end
                                       % 1       2      3      4     5    6     7     8     9    10     11    12   13   14       15        16       17        18     19   20      /end    
       % sample: self.activeOrders = [736270,    1,    215, 736344, 999, 2.01, 2.07, 2.04, 999,  999,   999,  74,  1,    0,       0,        0,       1];
                self.activeOrders = [self.mktInfo,repmat([0,-1],2,1),repmat(self.orderType,2,1)]; %and order for test-purpose
                
                self.activeOrders = cat(2,self.activeOrders,zeros(size(self.activeOrders,1),3));
                for i  = 1:size(self.activeOrders,1)
                    excutePrices = [self.activeOrders(i,[6,7]);self.activeOrders(i,[7,6]);self.activeOrders(i,[8,8])];
                    longshort = self.activeOrders(i,[13,14]);
                    ordersTypeVec = self.activeOrders(i,[15,16,17]);
                    gross = -longshort*excutePrices'*ordersTypeVec';
                    fee = abs(gross)*self.feeRate+self.fixFee;
                    net = gross - fee;
                    self.activeOrders(i,18:20) = [gross,fee,net];
                end
                
            end
            
            self.pendingOrders = cat(1,self.pendingOrders,self.activeOrders);
            
        end
        
        function settleExpiredOptions(self)
            %excute the expired options
            expiredPosition = self.netPosition(self.netPosition(:,3)==self.currentDay,:);
            self.expiredOrders = self.mktInfo(ismember(self.mktInfo(:,2:4),expiredPosition(:,1:3),'rows'),:);
            %                            1:12                            13,14                          15:17
            self.expiredOrders = cat(2,self.expiredOrders, [sufficientStat(-expiredPosition(:,4)),repmat(self.orderType,size(self.expiredOrders,1),1)], zeros(size(self.expiredOrders,1),3));
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
            %                1      2   3      4      5     6      7     8    9
            %netPosition: Put/Call  K  Exp  position  IV  Delta  Gross  Fee  Net
            
            self.excutedOrders = cat(1,self.excutedOrders,self.pendingOrders);
            self.cash = self.cash + sum(self.pendingOrders(:,20));
            self.pendingOrders = zeros(0,20);
            self.netPosition = self.netPosition(self.netPosition(:,4)~=0,:);
            self.markToMarket();
            self.netWorth = self.cash + self.portfolioMarketValue;
            
        end

 % Date  Put/Call  K    Exp   XX   bid   ask   mid   IV    Delta   F   DTE  Long Short limitOrder mktOrder midOrder GrossFlow Fee NetFlow   /end
% 1       2      3      4     5    6     7     8     9    10     11    12   13   14       15        16       17        18     19   20      /end    
       

    end
end
    
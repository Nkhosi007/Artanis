% Date  Put/Call  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE
% 1       2      3   4    5   6    7    8    9   10    11  12
% format longG
% Am I in issue 1?
classdef portfolio < handle
    properties
        master
        currentDay;
        oldMktInfo; %only for testing
        mktInfo;
        p0 = 210.389999;
        VIX = 22.7967654004844;
        ordersLog = [];
        netPosition;
        cash;
        netWorth;
        status = [];
        orders = [];
        activeOrders = [];
        expiredOrders = [];
        fixFee = 0;
        feeRate = 1/1000;
        grossSum;
        feeSum;
        netSum;
    end
    
    methods
        
        function VIX = genVIX(mktInfo)
            
        end
        
        function getMktInfo(self,newMktInfo)
            self.mktInfo = newMktInfo;
            self.currentDay = unique(self.mktInfo(:,1));
        end
            
        function policy(self)
            
            %policy starts here
            
            if self.VIX >19 %strategy for test-purpose
                                       % Date  Put/Call  K    Exp   XX   bid   ask   mid   IV    Delta   F   DTE  Long Short limitOrder mktOrder midOrder GrossFlow Fee NetFlow   /end
                                       % 1       2      3      4     5    6     7     8     9    10     11    12   13   14       15        16       17        18     19   20      /end    
       % sample: self.activeOrders = [736270,    1,    215, 736344, 999, 2.01, 2.07, 2.04, 999,  999,   999,  74,  1,    0,       0,        0,       1];
                self.activeOrders = [self.oldMktInfo,repmat([0,-1],2,1),repmat([0,1,0],2,1)]; %and order for test-purpose
                
                self.activeOrders = cat(2,self.activeOrders,zeros(size(self.activeOrders,1),3));
                for i  = 1:size(self.activeOrders,1)
                    excutePrices = [self.activeOrders(i,[6,7]);self.activeOrders(i,[7,6]);self.activeOrders(i,[8,8])];
                    longshort = self.activeOrders(i,[13,14]);
                    ordersType = self.activeOrders(i,[15,16,17]);
                    gross = longshort*excutePrices'*ordersType';
                    fee = abs(gross)*self.feeRate+self.fixFee;
                    net = gross - fee;
                    self.activeOrders(i,18:20) = [gross,fee,net];
                end
                
            end
            
            self.ordersLog = cat(1,self.ordersLog,self.activeOrders);
            
        end
        
        function settleExpiredOptions(self)
            %excute the expired options
            expiredOptions = self.ordersLog(self.ordersLog(:,4)==self.currentDay,:);
            self.expiredOrders = self.mktInfo(ismember(self.mktInfo(:,[2,3,4]),expiredOptions(:,[2,3,4]),'rows'),:);
            self.expiredOrders = cat(2,self.expiredOrders, [-expiredOptions(:,13:14),expiredOptions(:,15:end)]);
            for i  = 1:size(self.expiredOrders,1)
                    excutePrices = [self.expiredOrders(i,[6,7]);self.expiredOrders(i,[7,6]);self.expiredOrders(i,[8,8])];
                    longshort = self.expiredOrders(i,[13,14]);
                    ordersType = self.expiredOrders(i,[15,16,17]);
                    gross = longshort*excutePrices'*ordersType';
                    fee = abs(gross)*self.feeRate+self.fixFee;
                    net = gross - fee;
                    self.expiredOrders(i,18:20) = [gross,fee,net];
            end
            
            self.ordersLog = cat(1,self.ordersLog,self.expiredOrders);
            
        end
        
        function excute(self)
            
            
        end

 % Date  Put/Call  K    Exp   XX   bid   ask   mid   IV    Delta   F   DTE  Long Short limitOrder mktOrder midOrder GrossFlow Fee NetFlow   /end
% 1       2      3      4     5    6     7     8     9    10     11    12   13   14       15        16       17        18     19   20      /end    
       
        function getStatus(self)
            
            pointerList = unique(self.ordersLog(:,[2,3,4]),'rows');
            self.netPosition = [];
            for j = 1:size(pointerList,1)
                pointer = pointerList(j,:);
                specificInfo = self.ordersLog(self.ordersLog(:,2)==pointer(1)&...
                    self.ordersLog(:,3)==pointer(2)&...
                    self.ordersLog(:,4)==pointer(3),:);
                
                % Work Zone
%                 sum(specificInfo(:,[13,14]))   specificInfo(:,6:11)
%                 
%                 specificSum = [pointer,
%                 self.netPosition = cat(1,self.netPosition,specificOptionsInfo);
                
            end
            self.status = sum(self.ordersLog(:,[18,19,20]));
            self.grossSum = self.status(1);
            self.feeSum = self.status(2);
            self.netSum = self.status(3);
            
            disp(['Gross Profit: ',num2str(self.grossSum)]);
            disp(['Net Profit: ',num2str(self.netSum)]);
            disp(['Fee: ',num2str(self.feeSum)]);
        end
        
        function history = record()
        
        end
    end
end
    
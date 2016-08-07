% load('optionsSPY.mat'); 
date = unique(optionsSPY(:,1));


% Date  Put/Call  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE
% 1       2      3   4    5   6    7    8    9   10    11  12
window = 720:1800;
pfl = portfolio();
pfl.setOrderType('MD');
netWorthRec = [];
figure; hold on;
 
tic;
for i = window
    clc;
    disp(num2str(100*(i-window(1))/range(window)));
    day = date(i);
    mktInfo = optionsSPY(optionsSPY(:,1)==day,:);
    
    
    
    
    disp(pfl.netPosition(:,[1,2,3,4,7,10]));
    try
        pfl.getMktInfo(mktInfo);
        pfl.computeVIX();
        pfl.policy();
        pfl.settleExpiredOptions();
        pfl.excute();
        pfl.markToMarket();
    catch
    end
    netWorthRec(i) = pfl.netWorth;
    
    % dynamic plot

    
end
toc;
plot(netWorthRec(window(1):end));

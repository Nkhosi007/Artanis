% load('optionsSPY.mat'); 
date = unique(optionsSPY(:,1));


% Date  Put/Call  K  Exp  XX  bid  ask  mid  IV  Delta  F   DTE
% 1       2      3   4    5   6    7    8    9   10    11  12
window = 1871:1880;
for i = window
    day = date(i);
    mktInfo = optionsSPY(optionsSPY(:,1)==day &...
        optionsSPY(:,12)<37 & optionsSPY(:,12)>23,:);
    VIX = VIXlist(i,2);
    
    if VIX >19
        disp(mktInfo(:,[1,2,3,4,6,7,8]));
        actions = [day, 1, 175, 1;...
            day, 2, 180, -1];
    end
    
    
    
    
    
    
    
    
end
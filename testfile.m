% test file
dbstop if error;
format longG;

% dynamic plot
% figure; hold on;
% for j = 1:size(VIXlist,1)
% plot(VIXlist(1:j,2));
% drawnow;
% end

% load('optionsSPY.mat'); 
day1 = 736266;
day2 = 736267;
oldMktInfo = optionsSPY(optionsSPY(:,1)==day1,:);
newMktInfo = optionsSPY(optionsSPY(:,1)==day2,:);



day1 = 736266;
day2 = 736267;

myPfl = portfolio();
myPfl.setOrderType('MK');
% myPfl.oldMktInfo = oldMktInfo;
myPfl.getMktInfo(oldMktInfo);
myPfl.computeVIX();
myPfl.policy();
% myPfl.excute();
% myPfl.markToMarket();
% myPfl.getMktInfo(newMktInfo);
% myPfl.markToMarket();
% myPfl.settleExpiredOptions();
% % myPfl.excute();
% myPfl.computeVIX();
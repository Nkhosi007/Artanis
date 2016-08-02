% test file

% dynamic plot
% figure; hold on;
% for j = 1:size(VIXlist,1)
% plot(VIXlist(1:j,2));
% drawnow;
% end


% load('optionsSPY.mat'); 
dbstop if error;
day1 = 736266;
day2 = 736267;
oldMktInfo = optionsSPY(optionsSPY(:,4)==736267&optionsSPY(:,1)==736266&optionsSPY(:,3)==210,:);
mktInfo = optionsSPY(optionsSPY(:,1)==day2,:);
myPfl = portfolio();
myPfl.setOrderType('LM');
myPfl.oldMktInfo = oldMktInfo;
myPfl.getMktInfo(mktInfo);
myPfl.policy();
myPfl.policy();
myPfl.excute();
myPfl.settleExpiredOptions();
myPfl.excute();
disp(myPfl.cash);
function vec = sufficientStat(x)
if size(x,2) ~=1
    error('only support column vec');
end
pos = x; neg = x;
pos(pos<0) =0;
neg(neg>0) =0;
vec = [pos,neg];
end

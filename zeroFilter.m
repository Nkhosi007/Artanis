function result = zeroFilter(M,type)
[m,~] = size(M);
result = [];
if strcmpi(type,'call')
    for i = 1:m
        if i <=m-2

            if M(i,end)>0 
                result = cat(1,result,M(i,:));
            end

            if M(i+1,end)==0&&M(i+2,end)==0
                break;
            end

        else

            if M(i,end)>0 
                result = cat(1,result,M(i,:));
            end
        end
    end
elseif strcmpi(type,'put')
    for i = m:-1:1
        if i <3
            if M(i,end)>0
                result = cat(1,result,M(i,:));
            end
        else
            if M(i,end)>0
                result = cat(1,M(i,:),result);
            end
            
            if M(i-1,end)==0&&M(i-2,end)==0
                break;
            end
        end
    end
end
end